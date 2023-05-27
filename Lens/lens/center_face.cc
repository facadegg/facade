//
// Created by Shukant Pal on 5/20/23.
//

#include "internal.h"

namespace lens
{

center_face::~center_face() noexcept = default;

void center_face::run(const cv::Mat &image, std::vector<face_extraction> &extractions)
{
    cv::Mat resized_image;
    cv::resize(image, resized_image, cv::Size(640, 480));
    cv::cvtColor(resized_image, resized_image, cv::COLOR_BGRA2BGR);
    resized_image.convertTo(resized_image, CV_32FC3);

    cv::Mat heatmap;
    std::tuple<cv::Mat, cv::Mat> scales;
    std::tuple<cv::Mat, cv::Mat> offsets;
    std::vector<cv::Mat> landmarks(10, cv::Mat());

    run(resized_image, heatmap, scales, offsets, landmarks);

    // TODO: Use a OpenCV helper here
    bool p_found = false;
    float p_max = 0.35;
    size_t p_index = -1;
    int p_y = -1;
    int p_x = -1;
    for (int y = 0; y < heatmap.rows; y++)
    {
        for (int x = 0; x < heatmap.cols; x++)
        {
            size_t index = y * heatmap.cols + x;
            float probability = reinterpret_cast<float*>(heatmap.data)[index];

            if (probability > p_max)
            {
                p_found = true;
                p_max = probability;
                p_index = index;
                p_y = y;
                p_x = x;
            }
        }
    }

    extractions.clear();

    if (p_found)
    {
        float global_scale_x = 4.0f * (float) image.cols / static_cast<float>(resized_image.cols);
        float global_scale_y = 4.0f * (float) image.rows / static_cast<float>(resized_image.rows);

        float center_x = std::clamp((p_x + 0.5f + std::get<1>(offsets).at<float>(p_y, p_x)) * global_scale_x, 0.f, (float) image.cols);
        float center_y = std::clamp((p_y + 0.5f + std::get<0>(offsets).at<float>(p_y, p_x)) * global_scale_y, 0.f, (float) image.rows);
        float scale_x = std::exp(std::get<1>(scales).at<float>(p_y, p_x)) * global_scale_x;
        float scale_y = std::exp(std::get<0>(scales).at<float>(p_y, p_x)) * global_scale_y;

        float left = std::max(center_x - scale_x * 0.5f, 0.f);
        float top = std::max(center_y - scale_y * 0.5f, 0.f);
        float right = std::min(center_x + scale_x * 0.5f, static_cast<float>(image.cols));
        float bottom = std::min(center_y + scale_y * 0.5f, static_cast<float>(image.rows));

        lens::face_extraction extraction = {
                .bounds = cv::Rect2f(left, top, right - left, bottom - top),
        };

// #define DEBUG_FEATURE_CENTER_FACE
#ifdef DEBUG_FEATURE_CENTER_FACE
        cv::rectangle(image,
                      extraction.bounds.tl(),
                      extraction.bounds.br(),
                      cv::Scalar(255, 255, 0),
                      4);
#endif

        for (int i = 0; i < 5; i++) {
            const auto *landmarks_y = (const float *) landmarks.at(i * 2).data;
            const auto *landmarks_x = (const float *) landmarks.at(i * 2 + 1).data;

            extraction.landmarks[i].x = center_x + (landmarks_x[p_index] - 0.5f) * scale_x;
            extraction.landmarks[i].y = center_y + (landmarks_y[p_index] - 0.5f) * scale_y;

#ifdef DEBUG_FEATURE_CENTER_FACE
            cv::circle(image,
                       cv::Point(extraction.landmarks[i].x, extraction.landmarks[i].y),
                       4,
                       cv::Scalar(0, 255, 255),
                       4);
#endif
        }

        extractions.push_back(extraction);
    }
}

}