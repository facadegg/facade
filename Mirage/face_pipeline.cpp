//
// Created by Shukant Pal on 3/18/23.
//

#include <pthread.h>

#include <algorithm>
#include <iostream>
#include <onnxruntime/core/session/onnxruntime_c_api.h>
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>
#include <onnxruntime/core/providers/coreml/coreml_provider_factory.h>
#include <opencv2/opencv.hpp>
#include <utility>
#include "mirage.hpp"

Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "CenterFace");
Ort::SessionOptions session_options;

facade::video_pipeline::video_pipeline(facade_device *sink_device) :
    output_device(sink_device),
    input_queue(),
    g(),
    flow_control_delegate(input_queue),
    input_node(g, flow_control_delegate),
    face_extraction_node(g, 1, facade::video_pipeline::run_face_extraction),
    output_node(g, 1, facade::video_pipeline::run_output),
    output_ready(true)
{
    flow_control_delegate << this;

    oneapi::tbb::flow::make_edge(input_node, face_extraction_node);
    oneapi::tbb::flow::make_edge(face_extraction_node, output_node);

    OrtSessionOptionsAppendExecutionProvider_CoreML(session_options, COREML_FLAG_USE_NONE);

    center_face = new Ort::Session(env, "/opt/facade/CenterFace640x480.onnx", session_options);
    face_swap = new Ort::Session(env, "/opt/facade/Bryan_Greynolds.onnx", Ort::SessionOptions());
    face_mesh = new Ort::Session(env, "/opt/facade/FaceMesh.onnx", session_options);

    facade_error_code code = facade_write_open(output_device);
    std::cout << "open " << code << std::endl;
    facade_write_callback(output_device, reinterpret_cast<facade_callback>(video_pipeline::write_callback), this);
}

facade::video_pipeline::~video_pipeline()
{
    facade_write_close(output_device);
    facade_dispose_device(&output_device);

    delete center_face;
    delete face_swap;
    delete face_mesh;
}

void facade::video_pipeline::operator<<(facade::frame frame)
{
    vp_input input = { this, frame };
    auto extracted = video_pipeline::run_face_extraction(input);
    auto mesh = video_pipeline::run_face_mesh(extracted);
    video_pipeline::run_face_swap(mesh);
    video_pipeline::run_output(extracted);
}

facade::vp_face_extracted facade::video_pipeline::run_face_extraction(vp_input input)
{
    auto [pipeline, frame] = std::move(input);

    cv::Mat image(frame.height, frame.width, CV_8UC3, (void *) frame.pixels);
    cv::Size ml_size(640, 480);
    cv::Mat ml_image;

    cv::resize(image, ml_image, ml_size);
    ml_image.convertTo(ml_image, CV_32FC3);
    std::vector<cv::Mat> channels(3);
    cv::split(ml_image, channels);

    std::unique_ptr<float> ml_buffer(new float[640 * 480 * 3]);
    memcpy(ml_buffer.get(), channels[0].data, 640 * 480 * sizeof(float));
    memcpy(&ml_buffer.get()[640 * 480], channels[1].data, 640 * 480 * sizeof(float));
    memcpy(&ml_buffer.get()[640 * 480 * 2], channels[2].data, 640 * 480 * sizeof(float));

    Ort::MemoryInfo memory_info("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);
    const int64_t input_tensor_shape[4] = { 1, 3, 480, 640 };
    Ort::Value input_tensor = Ort::Value::CreateTensor<float>(memory_info, ml_buffer.get(), 640 * 480 * 3, input_tensor_shape, 4);

    static const char *input_name = "input.1";
    static const char *output_names[4] = {
            "537",
            "538",
            "539",
            "540"
    };
    Ort::RunOptions run_options{nullptr};

    std::vector<Ort::Value> output_tensors = pipeline->center_face->Run(run_options, &input_name, &input_tensor, 1, output_names, 4);
    Ort::Value& heatmaps_tensor = output_tensors[0];
    Ort::Value& scales_tensor = output_tensors[1];
    Ort::Value& offsets_tensor = output_tensors[2];
    Ort::Value& landmarks_tensor = output_tensors[3];
    std::vector<int64_t> heatmaps_shape = heatmaps_tensor.GetTensorTypeAndShapeInfo().GetShape();
    size_t rows = heatmaps_shape[2];
    size_t columns = heatmaps_shape[3];

    const float* heatmaps = heatmaps_tensor.GetTensorMutableData<float>();
    const float* scales_y = scales_tensor.GetTensorMutableData<float>();
    const float* scales_x = scales_y + (rows * columns);
    const float* offsets_y = offsets_tensor.GetTensorMutableData<float>();
    const float* offsets_x = offsets_y + (rows * columns);
    const float* landmarks = landmarks_tensor.GetTensorMutableData<float>();

    bool p_found = false;
    float p_max = 0.35;
    size_t p_index = -1;

    for (size_t y = 0; y < rows; y++)
    {
        for (size_t x = 0; x < columns; x++)
        {
            size_t index = y * columns + x;
            float probability = heatmaps[index];

            if (probability > p_max)
            {
                p_found = true;
                p_max = probability;
                p_index = index;
            }
        }
    }

    std::vector<face_extraction> extractions;

    if (p_found)
    {
        float p_x = static_cast<float>(p_index % columns);
        float p_y = static_cast<float>(p_index / columns);
        float global_scale_x = 4.0f * (float) frame.width / ml_size.width;
        float global_scale_y = 4.0f * (float) frame.height / ml_size.height;

        float center_x = std::clamp((p_x + 0.5f + offsets_x[p_index]) * global_scale_x, 0.f, (float) frame.width);
        float center_y = std::clamp((p_y + 0.5f + offsets_y[p_index]) * global_scale_y, 0.f, (float) frame.height);
        float scale_x = std::exp(scales_x[p_index]) * global_scale_x;
        float scale_y = std::exp(scales_y[p_index]) * global_scale_y;

        facade::face_extraction extraction = {
                .bounds = {
                        .left = std::max(center_x - scale_x * 0.5f, 0.f),
                        .top = std::max(center_y - scale_y * 0.5f, 0.f),
                        .right = std::min(center_x + scale_x * 0.5f, (float) frame.width),
                        .bottom = std::min(center_y + scale_y * 0.5f, (float) frame.height),
                },
        };

//#define DEBUG_FEATURE_CENTER_FACE
#ifdef DEBUG_FEATURE_CENTER_FACE
        cv::rectangle(image,
                      cv::Point(extraction.bounds.left, extraction.bounds.top),
                      cv::Point(extraction.bounds.right, extraction.bounds.bottom),
                      cv::Scalar(255, 255, 0),
                      4);
#endif

        for (int i = 0; i < 5; i++) {
            const float *landmarks_y = landmarks + 2 * i * rows * columns;
            const float *landmarks_x = landmarks + (2 * i + 1) * rows * columns;

            extraction.landmarks[i].x = center_x + (landmarks_x[p_index] - 0.5f) * scale_x;
            extraction.landmarks[i].y = center_y + (landmarks_y[p_index] - 0.5f) * scale_y;

#ifdef DEBUG
            cv::circle(image,
                       cv::Point(extraction.landmarks[i].x, extraction.landmarks[i].y),
                       4,
                       cv::Scalar(255, 255, 0),
                       4);
#endif
        }

        extractions.push_back(extraction);
    }

    return { pipeline, frame, extractions };
}

// Shinji Umeyama, PAMI 1991, DOI: 10.1109/34.88573
// https://www.cis.jhu.edu/software/lddmm-similitude/umeyama.pdf
int matrix_rank(const cv::Mat& A, double tol = 1e-8) {
    cv::Mat S;
    cv::SVD::compute(A, S);
    return cv::countNonZero(S > tol);
}


cv::Mat umeyama2(const cv::Mat& src, const cv::Mat& dst)
{
    int num = src.rows;
    int dim = src.channels();

    // Compute mean of src and dst.
    cv::Scalar src_mean = cv::mean(src);

    std::cout << "MEAN " << src_mean << std::endl;
    cv::Scalar dst_mean = cv::mean(dst);

    // Subtract mean from src and dst.
    cv::Mat src_demean = src - src_mean;
    cv::Mat dst_demean = dst - dst_mean;
    src_demean = src_demean.reshape(1, num);
    dst_demean = dst_demean.reshape(1, num);

    // Eq. (38).
    cv::Mat covariance = dst_demean.t() * src_demean / num;
    covariance.convertTo(covariance, CV_64F);

    // Eq. (39).
    cv::Mat d = cv::Mat::ones(dim, 1, CV_64F);
    if (cv::determinant(covariance) < 0) {
        d.at<double>(dim - 1, 0) = -1;
    }

    cv::Mat T = cv::Mat::eye(dim + 1, dim + 1, CV_64F);

    cv::Mat U, S, V;
    cv::SVD::compute(covariance, S, U, V);

    // Eq. (40) and (43).
    int rank = matrix_rank(covariance);
    if (rank == 0) {
        T.setTo(cv::Scalar(std::numeric_limits<double>::quiet_NaN()));
    } else if (rank == dim - 1) {
        if (cv::determinant(U) * cv::determinant(V) > 0) {
            T(cv::Rect(0, 0, dim, dim)) = cv::Mat(U * V);
        } else {
            double s = d.at<double>(dim - 1, 0);
            d.at<double>(dim - 1, 0) = -1;
            T(cv::Rect(0, 0, dim, dim)) = cv::Mat(U * cv::Mat::diag(d) * V);
            d.at<double>(dim - 1, 0) = s;
        }
    } else {
        T(cv::Rect(0, 0, dim, dim)) = U * cv::Mat::diag(d) * V;
    }

    // Eq. (41) and (42).
    double scale = S.dot(d) / (cv::mean(src_demean.mul(src_demean))[0] * dim);
    scale *= 0.6;
    T(cv::Rect(0, 0, dim, dim)) *= scale; // extra coverage by setting 0.5

    cv::Mat t = cv::Mat(cv::Vec2d(dst_mean[0], dst_mean[1])) -  T(cv::Rect(0, 0, dim, dim)) * cv::Vec2d(src_mean[0], src_mean[1]);
    t.copyTo(T(cv::Rect(dim, 0, 1, dim)));

    return T;
}

facade::vp_face_mesh facade::video_pipeline::run_face_mesh(vp_face_extracted args)
{
    static const char *INPUTS[1] = { "input_1" };
    static const char *OUTPUTS[1] = { "conv2d_21" };
    static const int64_t INPUT_SHAPES[1][4] = { { 1, 192, 192, 3 } };
    static const Ort::RunOptions RUN_OPTIONS{nullptr};
    static const Ort::MemoryInfo MEMORY_INFO("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);

    auto [pipeline, frame, extractions] = args;
    std::vector<facade::face> faces;

    cv::Mat texture(frame.height, frame.width, CV_8UC3, (void *) frame.pixels);
    cv::Mat image(frame.height, frame.width, CV_8UC3, (void *) frame.pixels);
    image = std::move(image.clone());
    image.convertTo(image, CV_32FC3);
    image *= 1.0f / 255.0f;

    for (auto face : extractions)
    {
        cv::Rect roi = cv::Rect(face.bounds.left, face.bounds.top,
                                face.bounds.width(), face.bounds.height());
        std::cout << roi << std::endl;
        cv::Mat face_image = image(roi);
        cv::resize(face_image, face_image, cv::Size(192, 192));

        Ort::Value input = Ort::Value::CreateTensor<float>(MEMORY_INFO,
                                                           reinterpret_cast<float *>(face_image.data),
                                                           face_image.total() * face_image.channels(),
                                                           INPUT_SHAPES[0],
                                                           4);
        std::vector<Ort::Value> outputs = pipeline->face_mesh->Run(RUN_OPTIONS,
                                                                   INPUTS, &input, 1,
                                                                   OUTPUTS, 1);
        Ort::Value& output = outputs[0];
        cv::Mat landmarks(3, 468, CV_32F, output.GetTensorMutableData<float>());

        landmarks = landmarks
                .clone()
                .reshape(3, 468)
                .mul(cv::Scalar(roi.width / 192., roi.height / 192.f, 1.f))
                + cv::Scalar(roi.x, roi.y);
        std::vector<cv::Mat> channels;
        cv::split(landmarks, channels);
        channels.pop_back();
        cv::merge(channels, landmarks);

        cv::Mat aligned_landmarks = NORMALIZED_FACIAL_LANDMARKS.clone();
        aligned_landmarks = aligned_landmarks.mul(cv::Scalar(224, 224));
        cv::Mat transform = umeyama2(landmarks, aligned_landmarks);

//#define DEBUG_FEATURE_FACE_MESH
#ifdef DEBUG_FEATURE_FACE_MESH
        for (int i = 0; i < landmarks.rows; i++)
        {
            auto landmark = landmarks.at<cv::Vec2f>(i);
            cv::circle(texture,
                       cv::Point(cvRound(landmark[0]), cvRound(landmark[1])),
                       1,
                       cv::Scalar(255, 255, 0),
                       2);
        }
#endif

        faces.push_back({ .bounds = roi, .landmarks = landmarks, .transform = transform });
    }

    return { pipeline, frame, faces };
}

Ort::AllocatorWithDefaultOptions allocator;

cv::Mat erode_blur(cv::Mat& img, int erode, int blur)
{
    cv::Mat out;
    cv::copyMakeBorder(img, out, img.rows, img.rows, img.cols, img.cols, cv::BORDER_CONSTANT);

    if (erode > 0) {
        cv::Mat el = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
        int iterations = std::max(1, erode / 2);
        cv::erode(out, out, el, cv::Point(-1, -1), iterations);
    } else if (erode < 0) {
        cv::Mat el = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
        int iterations = std::max(1, -erode / 2);
        cv::dilate(out, out, el, cv::Point(-1, -1), iterations);
    }

    if (true) {
        int h_clip_size = img.rows + blur / 2;
        int w_clip_size = img.cols + blur / 2;
        out(cv::Range(0, h_clip_size), cv::Range::all()).setTo(cv::Scalar(0));
        out(cv::Range(out.rows - h_clip_size, out.rows), cv::Range::all()).setTo(cv::Scalar(0));
        out(cv::Range::all(), cv::Range(0, w_clip_size)).setTo(cv::Scalar(0));
        out(cv::Range::all(), cv::Range(out.cols - w_clip_size, out.cols)).setTo(cv::Scalar(0));
    }

    if (blur > 0) {
        double sigma = blur * 0.125 * 2;
        cv::GaussianBlur(out, out, cv::Size(0, 0), sigma);
    }

    out = out(cv::Range(img.rows, out.rows - img.rows),
              cv::Range(img.cols, out.cols - img.cols));

    return out;
}

cv::Mat rct(cv::Mat& src, cv::Mat& like)
{
    cv::Mat src_lab, like_lab;
    cv::cvtColor(src, src_lab, cv::COLOR_BGR2Lab);
    cv::cvtColor(like, like_lab, cv::COLOR_BGR2Lab);

    cv::Scalar src_mean, src_std, like_mean, like_std;
    cv::meanStdDev(src_lab, src_mean, src_std);
    cv::meanStdDev(like_lab, like_mean, like_std);

    cv::Mat out = src_lab.clone() - src_mean;

    std::vector<cv::Mat> out_channels;
    cv::split(out, out_channels);

    for (int c = 0; c < out.channels(); c++)
    {
        out_channels[c].convertTo(out_channels[c], CV_32F);
        out_channels[c] *= like_std[c] / src_std[c];
    }

    cv::merge(out_channels, out);
    out += like_mean;

    // Clip L*, a*, and b* channels to their valid ranges
    src_lab.setTo(cv::Scalar(0, -127, -127), src_lab < cv::Scalar(0, -127, -127));
    src_lab.setTo(cv::Scalar(100, 127, 127), src_lab > cv::Scalar(100, 127, 127));

    cv::cvtColor(out, out, cv::COLOR_Lab2BGR);

    return out;
}

facade::vp_face_mesh facade::video_pipeline::run_face_swap(vp_face_mesh args)
{
    auto [pipeline, frame, extractions] = args;

    if (!extractions.empty())
    {
        face& extraction = extractions[0];

        std::vector<int64_t> input_shape = std::move(pipeline->face_swap
                ->GetInputTypeInfo(0).GetTensorTypeAndShapeInfo().GetShape());
        const int64_t swap_height = input_shape[1];
        const int64_t swap_width = input_shape[2];

        cv::Mat frame_image(frame.height, frame.width, CV_8UC3, (void *) frame.pixels);
        cv::Rect roi = extraction.bounds;
        cv::Mat face_image = std::move(frame_image(roi));
        cv::Mat swap_image;
        cv::warpAffine(frame_image, swap_image, extraction.transform(cv::Rect(0, 0, 3, 2)), cv::Size(swap_width, swap_height));
//        cv::resize(face_image, swap_image, cv::Size(swap_width, swap_height));
        swap_image.convertTo(swap_image, CV_32FC3);

        cv::Mat si_clone = swap_image.clone();
        cv::multiply(si_clone, cv::Scalar(1.f/255.f, 1.f/255.f, 1.f/255.f), si_clone);

        Ort::MemoryInfo memory_info("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);
        const int64_t input_tensor_shape[4] = { 1, swap_height, swap_width, 3 };

        static const char *input_names[1] = { "in_face:0" };
        Ort::Value input_tensors[1] = {
                Ort::Value::CreateTensor<float>(memory_info,
                                                reinterpret_cast<float *>(si_clone.data),
                                                swap_height * swap_width * 3,
                                                input_tensor_shape, 4),
        };

        static const char *output_names[3] = {
                "out_face_mask:0",
                "out_celeb_face:0",
                "out_celeb_face_mask:0",
        };
        Ort::RunOptions run_options{nullptr};
        auto start_time = std::chrono::high_resolution_clock::now();
        std::vector<Ort::Value> output_tensors = pipeline->face_swap->Run(run_options, input_names, input_tensors, 1, output_names, 3);
        auto end_time = std::chrono::high_resolution_clock::now();
        std::cout << " TIME WAS " <<  std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count() << std::endl;
        Ort::Value& out_celeb_face_tensor = output_tensors[1];
        Ort::Value& out_celeb_face_mask_tensor = output_tensors[2];

        cv::Mat out_celeb_face(swap_height, swap_width, CV_32FC3, out_celeb_face_tensor.GetTensorMutableData<float>());
        cv::Mat out_celeb_face_mask(swap_height, swap_width, CV_32FC1, out_celeb_face_mask_tensor.GetTensorMutableData<float>());

        cv::cvtColor(out_celeb_face_mask, out_celeb_face_mask, cv::COLOR_GRAY2RGB);

        out_celeb_face_mask = std::move(erode_blur(out_celeb_face_mask, 5, 25));
        out_celeb_face = std::move(rct(out_celeb_face, si_clone));

        cv::multiply(out_celeb_face, cv::Scalar(255, 255, 255), out_celeb_face);
        cv::multiply(out_celeb_face, out_celeb_face_mask, out_celeb_face);

        cv::multiply(out_celeb_face_mask, cv::Scalar(-1, -1, -1), out_celeb_face_mask);
        cv::add(out_celeb_face_mask, cv::Scalar(1, 1, 1), out_celeb_face_mask);

//#define DEBUG_FEATURE_FACE_SWAP_WITH_NO_COMPOSITE
#ifndef DEBUG_FEATURE_FACE_SWAP_WITH_NO_COMPOSITE
        cv::multiply(swap_image, out_celeb_face_mask, swap_image);
        cv::add(swap_image, out_celeb_face, swap_image);
#endif

        cv::Mat out_celeb_face_ui(swap_height, swap_width, CV_8UC3);
        swap_image.convertTo(out_celeb_face_ui, CV_8UC3);

#ifndef DEBUG_FEATURE_FACE_SWAP_WITH_NO_COMPOSITE
        cv::Mat new_layer;
        cv::warpAffine(out_celeb_face_ui, new_layer,
                       extraction.transform.inv()(cv::Rect(0, 0, 3, 2)),
                       cv::Size(frame_image.cols, frame_image.rows));
        cv::Mat new_layer_mask = new_layer.clone();

        cv::threshold(new_layer_mask,
                      new_layer_mask,
                      1.0,
                      1.0,
                      cv::THRESH_BINARY);
        new_layer_mask = cv::Scalar(1, 1, 1) - new_layer_mask;

        frame_image = frame_image.mul(new_layer_mask);

        cv::add(frame_image, new_layer, frame_image);
#else
        cv::resize(out_celeb_face_ui, frame_image(roi), cv::Size(roi.width, roi.height));
#endif
    }

    return args;
}

facade::vp_output facade::video_pipeline::run_output(vp_face_extracted args)
{
    auto [pipeline, frame, extractions] = std::move(args);

    pipeline->output_queue.push(frame);

    if (pipeline->output_ready)
        write_callback(pipeline);

    return (int) extractions.size();
}

void facade::video_pipeline::write_callback(facade::video_pipeline *pipeline)
{
    pipeline->write_mutex.lock();

    facade::frame frame = {};

    if (pipeline->output_queue.try_pop(frame))
    {
        cv::Mat frame_image(frame.height, frame.width, CV_8UC3, (void *) frame.pixels);
        cv::Mat rgba_image(frame.height, frame.width, CV_8UC4);
        cv::cvtColor(frame_image, rgba_image, cv::COLOR_BGR2BGRA);

        facade_write_frame(pipeline->output_device,
                           (void *) rgba_image.data,
                           4 * frame.width * frame.height);
        delete frame.pixels;

        pipeline->output_ready = false; // Wait for next write_callback
    }
    else
    {
        pipeline->output_ready = true; // Missed this frame call so push once next frame is available
    }

    pipeline->write_mutex.unlock();
}
