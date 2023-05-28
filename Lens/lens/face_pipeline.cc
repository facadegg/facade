//
// Created by Shukant Pal on 3/18/23.
//

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <opencv2/opencv.hpp>
#include <utility>

#include "internal.h"
#include "lens.h"

namespace fs = std::filesystem;

namespace lens
{

const fs::path center_face_filename = "CenterFace.mlmodel";
const fs::path face_mesh_filename = "FaceMesh.mlmodel";

face_pipeline::face_pipeline(facade_device *sink_device,
                             const fs::path &root_dir,
                             const fs::path &face_swap_model) :
    output_device(sink_device),
    frame_interval_mean(1000.0 / sink_device->frame_rate),
    frame_counter_read(0),
    frame_counter_write(0),
    frame_write_timestamp(std::chrono::high_resolution_clock::now()),
    center_face(center_face::build((root_dir / center_face_filename).string())),
    face_mesh(face_mesh::build((root_dir / face_mesh_filename).string())),
    face_swap(face_swap::build(face_swap_model, root_dir)),
    input_queue(),
    output_queue(),
    output_ready(true)
{
    assert(center_face != nullptr);
    assert(face_mesh != nullptr);
    assert(face_swap != nullptr);

    const int pool_capacity = 4;
    input_queue.set_capacity(pool_capacity);
    output_queue.set_capacity(pool_capacity);
    for (int i = 0; i < pool_capacity; i++)
        thread_pool.emplace_back(&face_pipeline::run, this);

    facade_error_code code = facade_write_open(output_device);
    std::cout << "open " << code << std::endl;
    facade_write_callback(
        output_device, reinterpret_cast<facade_callback>(face_pipeline::write_stub), this);
}

face_pipeline::~face_pipeline()
{
    facade_write_close(output_device);
    facade_dispose_device(&output_device);
}

void face_pipeline::operator<<(cv::Mat &image)
{
    ++frame_counter_read;
    auto *data = reinterpret_cast<uint8_t *>(image.data);

    if (!this->input_queue.try_push(std::move(image)))
    {
        delete[] data;
    }
}

[[noreturn]] void face_pipeline::run()
{
    cv::Mat image;
    std::vector<face_extraction> extractions;
    std::vector<face> faces;
    std::vector<face> face_memory;

    while (true)
    {
        input_queue.pop(image);

        extractions.clear();
        faces.clear();

        center_face->run(image, extractions);
        run_temporal_smoothing<face_extraction>(
            extractions, face_memory, face_pipeline::smooth_face_bounds);
        run_face_alignment(image, extractions, faces);

        face_memory = faces;

        run_face_swap(image, faces, [this](cv::Mat &image) { this->submit(image); });
    }
}

template <typename T>
void face_pipeline::run_temporal_smoothing(std::vector<T> &observed_faces,
                                           const std::vector<face> &remembered_faces,
                                           const std::function<void(T &, const face &)> &callback)
{
    for (int i = 0; i < std::min(observed_faces.size(), remembered_faces.size()); i++)
    {
        T &observed_face = observed_faces[i];
        const face &remembered_face = remembered_faces[i];
        const int overlap_left =
            std::max<int>(observed_face.bounds.tl().x, remembered_face.bounds.tl().x);
        const int overlap_top =
            std::max<int>(observed_face.bounds.tl().y, remembered_face.bounds.tl().y);
        const int overlap_right =
            std::min<int>(observed_face.bounds.br().x, remembered_face.bounds.br().x);
        const int overlap_bottom =
            std::min<int>(observed_face.bounds.br().y, remembered_face.bounds.br().y);

        if (overlap_right <= overlap_left || overlap_bottom <= overlap_top)
            continue;

        const int overlap_area = (overlap_right - overlap_left) * (overlap_bottom - overlap_top);
        const double overlap = static_cast<double>(overlap_area) / observed_face.bounds.area();

        if (overlap > .98)
        {
            callback(observed_face, remembered_face);
        }
    }
}

void face_pipeline::run_face_alignment(cv::Mat &image,
                                       const std::vector<face_extraction> &extractions,
                                       std::vector<face> &faces)
{
    for (auto face : extractions)
    {
        cv::Mat landmarks;
        face_mesh->run(image, face, landmarks);

        assert(landmarks.channels() == 2);
        assert(landmarks.rows == NORMALIZED_FACIAL_LANDMARKS.rows);

        const double coverage = 2;

        cv::Mat aligned_landmarks = NORMALIZED_FACIAL_LANDMARKS.clone();
        aligned_landmarks = aligned_landmarks.mul(cv::Scalar(224 / coverage, 224 / coverage)) +
                            cv::Scalar(112 * (1 - 1 / coverage), 112 * (1 - 1 / coverage));
        cv::Mat transform = umeyama2(landmarks, aligned_landmarks);

#ifdef LENS_FEATURE_DEBUG_FACE_MESH
        for (int i = 0; i < landmarks.rows; i++)
        {
            auto landmark = landmarks.at<cv::Vec2f>(i);

            if (i == 6)
            {
                cv::circle(image,
                           cv::Point(cvRound(landmark[0]), cvRound(landmark[1])),
                           8,
                           cv::Scalar(0, 255, 0),
                           6);
            }
            else
            {
                cv::circle(image,
                           cv::Point(cvRound(landmark[0]), cvRound(landmark[1])),
                           1,
                           cv::Scalar(255, 255, 0),
                           2);
            }
        }
#endif

#ifdef LENS_FEATURE_DEBUG_CENTER_FACE
        const cv::Mat inv = transform.inv()(cv::Rect(0, 0, 3, 2));
        const auto a = inv.at<double>(0, 0);
        const auto b = inv.at<double>(0, 1);
        const auto tx = inv.at<double>(0, 2);
        const auto c = inv.at<double>(1, 0);
        const auto d = inv.at<double>(1, 1);
        const auto ty = inv.at<double>(1, 2);
        const cv::Point2f rect[4] = {
            cv::Point2f(a * 0 + b * 0 + tx, c * 0 + b * 0 + ty),
            cv::Point2f(a * 224 + b * 0 + tx, c * 224 + d * 0 + ty),
            cv::Point2f(a * 224 + b * 224 + tx, c * 224 + d * 224 + ty),
            cv::Point2f(a * 0 + b * 224 + tx, c * 0 + d * 224 + ty),
        };

        for (int i = 0; i < 4; i++)
        {
            std::cout << rect[i] << std::endl;
            cv::line(image, rect[i], rect[(i + 1) % 4], cv::Scalar(0, 255, 0), 4);
        }
#endif

        faces.push_back({.bounds = face.bounds, .landmarks = landmarks, .transform = transform});
    }
}

void face_pipeline::run_face_swap(cv::Mat &image,
                                  const std::vector<face> &faces,
                                  std::function<void(cv::Mat &)> callback)
{
    if (!faces.empty())
    {
        const auto &face = faces[0];
        const int64_t swap_height = 224;
        const int64_t swap_width = 224;

        cv::Mat swap_image;
        cv::warpAffine(image,
                       swap_image,
                       face.transform(cv::Rect(0, 0, 3, 2)),
                       cv::Size(swap_width, swap_height));
        cv::cvtColor(swap_image, swap_image, cv::COLOR_BGRA2BGR);
        swap_image.convertTo(swap_image, CV_32FC3);

        cv::Mat si_clone = swap_image.clone();
        cv::multiply(si_clone, cv::Scalar(1.f / 255.f, 1.f / 255.f, 1.f / 255.f), si_clone);

        cv::Mat out_celeb_face, out_celeb_face_mask;
        face2face *result = nullptr;

        result = face_swap->run(si_clone);

        face_swap->composite(image, face, &result, std::move(callback));
    }
    else
    {
        callback(image);
    }
}

void face_pipeline::submit(cv::Mat &image)
{
    if (!output_queue.try_push(image))
        delete[] reinterpret_cast<uint8_t *>(image.data);
    else if (output_ready)
        write();
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
            composited_image =
                cv::Mat::zeros(cv::Size(output_device->width, output_device->height), CV_8UC4);
            cv::Rect placement;

            float scale = std::min(1.f,
                                   std::min(static_cast<float>(composited_image.rows) /
                                                static_cast<float>(frame_image.rows),
                                            static_cast<float>(composited_image.cols) /
                                                static_cast<float>(frame_image.cols)));

            placement.width = frame_image.cols * scale;
            placement.height = frame_image.rows * scale;
            placement.x = (composited_image.cols - placement.width) * 0.5f;
            placement.y = (composited_image.rows - placement.height) * 0.5f;

            std::cout << "TO " << placement << "with scale " << scale << std::endl;

            cv::resize(frame_image, frame_image, placement.size());
            frame_image.copyTo(composited_image(placement));
        }

        facade_write_frame(output_device,
                           (void *)composited_image.data,
                           4 * composited_image.cols * composited_image.rows);
        delete[] const_cast<uint8_t *>(frame_image.data);

        auto now = std::chrono::high_resolution_clock::now();
        size_t frame_interval_sample =
            std::chrono::duration_cast<std::chrono::milliseconds>(now - frame_write_timestamp)
                .count();
        frame_interval_mean =
            .9 * frame_interval_mean + .1 * static_cast<double>(frame_interval_sample);
        ++frame_counter_write;

        std::cout << "frame_rate=" << std::floor(1000 / frame_interval_mean) << " | "
                  << "throughput="
                  << static_cast<float>(frame_counter_write) /
                         static_cast<float>(frame_counter_read) * 100
                  << "%" << std::endl;
        frame_write_timestamp = now;

        output_ready = false; // Wait for next write
    }
    else
    {
        output_ready = true; // Missed this frame call so push once next frame is available
    }

    write_mutex.unlock();
}

// Shinji Umeyama, PAMI 1991, DOI: 10.1109/34.88573
// https://www.cis.jhu.edu/software/lddmm-similitude/umeyama.pdf
int matrix_rank(const cv::Mat &A, double tol = 1e-8)
{
    cv::Mat S;
    cv::SVD::compute(A, S);
    return cv::countNonZero(S > tol);
}

cv::Mat face_pipeline::umeyama2(const cv::Mat &src, const cv::Mat &dst)
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
    if (cv::determinant(covariance) < 0)
    {
        d.at<double>(dim - 1, 0) = -1;
    }

    cv::Mat T = cv::Mat::eye(dim + 1, dim + 1, CV_64F);

    cv::Mat U, S, V;
    cv::SVD::compute(covariance, S, U, V);

    // Eq. (40) and (43).
    int rank = matrix_rank(covariance);
    if (rank == 0)
    {
        T.setTo(cv::Scalar(std::numeric_limits<double>::quiet_NaN()));
    }
    else if (rank == dim - 1)
    {
        if (cv::determinant(U) * cv::determinant(V) > 0)
        {
            T(cv::Rect(0, 0, dim, dim)) = cv::Mat(U * V);
        }
        else
        {
            double s = d.at<double>(dim - 1, 0);
            d.at<double>(dim - 1, 0) = -1;
            T(cv::Rect(0, 0, dim, dim)) = cv::Mat(U * cv::Mat::diag(d) * V);
            d.at<double>(dim - 1, 0) = s;
        }
    }
    else
    {
        T(cv::Rect(0, 0, dim, dim)) = U * cv::Mat::diag(d) * V;
    }

    // Eq. (41) and (42).
    double scale = S.dot(d) / (cv::mean(src_demean.mul(src_demean))[0] * dim);
    //    scale *= 0.6;
    T(cv::Rect(0, 0, dim, dim)) *= scale; // extra coverage by setting 0.5

    cv::Mat t = cv::Mat(cv::Vec2d(dst_mean[0], dst_mean[1])) -
                T(cv::Rect(0, 0, dim, dim)) * cv::Vec2d(src_mean[0], src_mean[1]);
    t.copyTo(T(cv::Rect(dim, 0, 1, dim)));

    return T;
}

void face_pipeline::smooth_face_bounds(face_extraction &observed_face, const face &remembered_face)
{
    constexpr double lerp = .33;
    observed_face.bounds.x =
        static_cast<float>(observed_face.bounds.x * (1 - lerp) + remembered_face.bounds.x * lerp);
    observed_face.bounds.y =
        static_cast<float>(observed_face.bounds.y * (1 - lerp) + remembered_face.bounds.y * lerp);
    observed_face.bounds.width = static_cast<float>(observed_face.bounds.width * (1 - lerp) +
                                                    remembered_face.bounds.width * lerp);
    observed_face.bounds.height = static_cast<float>(observed_face.bounds.height * (1 - lerp) +
                                                     remembered_face.bounds.height * lerp);
}

void face_pipeline::write_stub(face_pipeline *pipeline) { pipeline->write(); }

} // namespace lens
