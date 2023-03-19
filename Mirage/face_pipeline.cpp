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

    center_face = new Ort::Session(env, "/Users/shukantpal/Downloads/CenterFace640x480.onnx", session_options);
    face_swap = new Ort::Session(env, "/Users/shukantpal/Downloads/Mr_Bean_pinned.onnx", Ort::SessionOptions());

    facade_error_code code = facade_write_open(output_device);
    std::cout << "open " << code << std::endl;
    facade_write_callback(output_device, reinterpret_cast<facade_callback>(video_pipeline::write_callback), this);
}

void facade::video_pipeline::operator<<(facade::frame frame)
{
    vp_input input = { this, frame };
    auto extracted = video_pipeline::run_face_extraction(input);
    extracted = video_pipeline::run_face_swap(extracted);
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

    std::cout << "P IS " << p_max << std::endl;

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

//        cv::rectangle(image,
//                      cv::Point(extraction.bounds.left, extraction.bounds.top),
//                      cv::Point(extraction.bounds.right, extraction.bounds.bottom),
//                      cv::Scalar(255, 255, 0),
//                      4);

        for (int i = 0; i < 5; i++) {
            const float *landmarks_y = landmarks + 2 * i * rows * columns;
            const float *landmarks_x = landmarks + (2 * i + 1) * rows * columns;

            extraction.landmarks[i].x = center_x + (landmarks_x[p_index] - 0.5f) * scale_x;
            extraction.landmarks[i].y = center_y + (landmarks_y[p_index] - 0.5f) * scale_y;

//            cv::circle(image,
//                       cv::Point(extraction.landmarks[i].x, extraction.landmarks[i].y),
//                       4,
//                       cv::Scalar(255, 255, 0),
//                       4);
        }

        extractions.push_back(extraction);
    }

    return { pipeline, frame, extractions };
}

Ort::AllocatorWithDefaultOptions allocator;

facade::vp_face_extracted facade::video_pipeline::run_face_swap(vp_face_extracted args)
{
    auto [pipeline, frame, extractions] = args;

    if (!extractions.empty())
    {
        face_extraction& extraction = extractions[0];

        std::vector<int64_t> input_shape = std::move(pipeline->face_swap
                ->GetInputTypeInfo(0).GetTensorTypeAndShapeInfo().GetShape());
        const int64_t swap_height = input_shape[1];
        const int64_t swap_width = input_shape[2];

        cv::Mat frame_image(frame.height, frame.width, CV_8UC3, (void *) frame.pixels);
        cv::Rect roi(extraction.bounds.left, extraction.bounds.top,
                     extraction.bounds.width(), extraction.bounds.height());
        cv::Mat face_image = std::move(frame_image(roi));
        cv::Mat swap_image;
        cv::resize(face_image, swap_image, cv::Size(swap_width, swap_height));
        swap_image.convertTo(swap_image, CV_32FC3);

        cv::Mat si_clone = swap_image.clone();
        cv::multiply(si_clone, cv::Scalar(1.f/255.f, 1.f/255.f, 1.f/255.f), si_clone);

        Ort::MemoryInfo memory_info("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);
        const int64_t input_tensor_shape[4] = { 1, swap_height, swap_width, 3 };

        static const char *input_names[1] = {
                "in_face:0",
        };
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

        cv::multiply(out_celeb_face, cv::Scalar(255, 255, 255), out_celeb_face);
        cv::multiply(out_celeb_face, out_celeb_face_mask, out_celeb_face);

        cv::multiply(out_celeb_face_mask, cv::Scalar(-1, -1, -1), out_celeb_face_mask);
        cv::add(out_celeb_face_mask, cv::Scalar(1, 1, 1), out_celeb_face_mask);

        cv::multiply(swap_image, out_celeb_face_mask, swap_image);
        cv::add(swap_image, out_celeb_face, swap_image);


        cv::Mat out_celeb_face_ui(swap_height, swap_width, CV_8UC3);
        swap_image.convertTo(out_celeb_face_ui, CV_8UC3);
        cv::resize(out_celeb_face_ui, frame_image(roi), cv::Size(roi.width, roi.height));
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
