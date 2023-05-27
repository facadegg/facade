//
// Created by Shukant Pal on 3/18/23.
//

#include <algorithm>
#include <iostream>
#include <filesystem>
#include <opencv2/opencv.hpp>
#include <utility>

#include "internal.h"
#include "lens.h"

auto last_push_time = std::chrono::high_resolution_clock::now();

namespace fs = std::filesystem;

namespace lens
{

const fs::path center_face_filename = "CenterFace.mlmodel";
const fs::path face_mesh_filename = "FaceMesh.mlmodel";

lens::face_pipeline::face_pipeline(facade_device *sink_device, const fs::path& root_dir, const std::filesystem::path& face_swap_model) :
        output_device(sink_device),
        frame_interval_mean(1000.0 / sink_device->frame_rate),
        frame_counter_read(0),
        frame_counter_write(0),
        input_queue(),
        output_queue(),
        output_ready(true),
        center_face(center_face::build((root_dir / center_face_filename).string())),
        face_mesh(face_mesh::build((root_dir / face_mesh_filename).string())),
        face_swap(face_swap::build(face_swap_model))
{
    const std::string center_face_path = (root_dir / center_face_filename).string();
    const std::string face_mesh_path = (root_dir / face_mesh_filename).string();

    std::cout << " root_dir " << root_dir << " center " << center_face_path << std::endl;

    if (!center_face)
    {
        throw std::runtime_error("Failed to initialize center_face");
    }

    const int pool_capacity = 4;
    input_queue.set_capacity(pool_capacity);
    output_queue.set_capacity(pool_capacity);
    for (int i = 0; i < pool_capacity; i++)
        thread_pool.emplace_back(&face_pipeline::run, this, i);

    facade_error_code code = facade_write_open(output_device);
    std::cout << "open " << code << std::endl;
    facade_write_callback(output_device, reinterpret_cast<facade_callback>(face_pipeline::write_stub), this);
}

lens::face_pipeline::~face_pipeline()
{
    facade_write_close(output_device);
    facade_dispose_device(&output_device);

//    delete face_swap;
}

void lens::face_pipeline::operator<<(lens::frame frame)
{
    bool success = this->input_queue.try_push(frame);
    ++frame_counter_read;

    if (!success)
    {
        delete[] frame.pixels;
    }
//    std::cout << "pushed: " << success << std::endl;
}

void face_pipeline::run(int id)
{
    lens::frame frame = { };

    while (true)
    {
        input_queue.pop(frame);
        auto end_time = std::chrono::high_resolution_clock::now();

        vp_input input = { this, frame };
        auto extracted = face_pipeline::run_face_extraction(input);
        auto mesh = face_pipeline::run_face_mesh(extracted);
        face_pipeline::run_face_swap(mesh);
    }
}

void face_pipeline::submit(cv::Mat& image)
{
    output_queue.try_push(image);
    if (output_ready)
        write();
}

lens::vp_face_extracted lens::face_pipeline::run_face_extraction(vp_input input)
{
    auto [pipeline, frame] = std::move(input);

    cv::Mat image(frame.height, frame.width, CV_8UC4, (void *) frame.pixels);
    std::vector<face_extraction> extractions;

    pipeline->center_face->run(image, extractions);

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

lens::vp_face_mesh lens::face_pipeline::run_face_mesh(vp_face_extracted args)
{
    auto [pipeline, frame, extractions] = args;
    std::vector<lens::face> faces;

    cv::Mat image(frame.height, frame.width, CV_8UC4, (void *) frame.pixels);

    for (auto face : extractions)
    {
        auto roi = cv::Rect(face.bounds);
        cv::Mat face_image = image(roi);

        cv::Mat landmarks;
        pipeline->face_mesh->run(face_image, landmarks);

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

            if (i == 249) {
                cv::circle(texture,
                           cv::Point(cvRound(landmark[0]), cvRound(landmark[1])),
                           8,
                           cv::Scalar(0, 255, 0),
                           6);
            } else {
                cv::circle(texture,
                           cv::Point(cvRound(landmark[0]), cvRound(landmark[1])),
                           1,
                           cv::Scalar(255, 255, 0),
                           2);

            }
        }
#endif

        faces.push_back({ .bounds = roi, .landmarks = landmarks, .transform = transform });
    }

    return { pipeline, frame, faces };
}

lens::vp_face_mesh lens::face_pipeline::run_face_swap(vp_face_mesh args)
{
    auto [pipeline, frame, extractions] = args;

    if (!extractions.empty())
    {
        face& extraction = extractions[0];

        const int64_t swap_height = 224;
        const int64_t swap_width = 224;

        cv::Mat frame_image(frame.height, frame.width, CV_8UC4, (void *) frame.pixels);
        cv::Rect roi = extraction.bounds;
        cv::Mat face_image = std::move(frame_image(roi));
        cv::Mat swap_image;
        cv::warpAffine(frame_image, swap_image, extraction.transform(cv::Rect(0, 0, 3, 2)), cv::Size(swap_width, swap_height));
        cv::cvtColor(swap_image, swap_image, cv::COLOR_BGRA2BGR);
        swap_image.convertTo(swap_image, CV_32FC3);

        cv::Mat si_clone = swap_image.clone();
        cv::multiply(si_clone, cv::Scalar(1.f/255.f, 1.f/255.f, 1.f/255.f), si_clone);

        cv::Mat out_celeb_face, out_celeb_face_mask;
        face2face* result = nullptr;

        if (pipeline->face_swap)
        {
            result = pipeline->face_swap->run(si_clone);
        }
        else
        {
            throw std::runtime_error("No model executor available");
        }

        face_pipeline* alias = pipeline;

        pipeline->face_swap->composite(frame_image,
                                       extraction,
                                       &result,
                                       [alias](cv::Mat& image) { alias->submit(image); });
    }

    return args;
}

void face_pipeline::write()
{
    write_mutex.lock();

    cv::Mat frame_image;

    if (output_queue.try_pop(frame_image))
    {
        cv::Mat composited_image;

        if (output_device->width == frame_image.cols && output_device->height)
        {
            composited_image = frame_image;
        }
        else
        {
            composited_image = cv::Mat::zeros(cv::Size(output_device->width, output_device->height), CV_8UC4);
            cv::Rect placement;

            float src_aspect_ratio = frame_image.cols / frame_image.rows;
            float dst_aspect_ratio = composited_image.cols / composited_image.rows;
            float scale = std::min(1.f, std::min(static_cast<float>(composited_image.rows) / static_cast<float>(frame_image.rows),
                                                 static_cast<float>(composited_image.cols) / static_cast<float>(frame_image.cols)));

            placement.width = frame_image.cols * scale;
            placement.height = frame_image.rows * scale;
            placement.x = (composited_image.cols - placement.width) * 0.5f;
            placement.y = (composited_image.rows - placement.height) * 0.5f;

            std::cout << "TO " << placement << "with scale " << scale << std::endl;

            cv::resize(frame_image, frame_image, placement.size());
            frame_image.copyTo(composited_image(placement));
        }

        facade_write_frame(output_device,
                           (void *) composited_image.data,
                           4 * composited_image.cols * composited_image.rows);
        delete[] const_cast<uint8_t*>(frame_image.data);

        auto end_time = std::chrono::high_resolution_clock::now();
        double frame_interval_sample =  std::chrono::duration_cast<std::chrono::milliseconds>(end_time - last_push_time).count();
        frame_interval_mean = .9 * frame_interval_mean + .1 * frame_interval_sample;
        ++frame_counter_write;

        std::cout << "frame_rate=" << std::floor(1000 / frame_interval_mean) << " | "
                  << "throughput=" << static_cast<float>(frame_counter_write) / static_cast<float>(frame_counter_read) * 100 << "%"
                  << std::endl;
        last_push_time = end_time;

        output_ready = false; // Wait for next write
    }
    else
    {
        output_ready = true; // Missed this frame call so push once next frame is available
    }

    write_mutex.unlock();
}

void face_pipeline::write_stub(face_pipeline* pipeline)
{
    pipeline->write();
}

} // namespace lens