//
// Created by Shukant Pal on 5/28/23.
//

#include "internal.h"

namespace lens
{

face_mesh::~face_mesh() noexcept = default;

void face_mesh::run(const cv::Mat &image, const face_extraction &face, cv::Mat &landmarks_2d)
{
    assert(image.channels() == 4);

    const cv::Point2f &left_eye = face.landmarks[LEFT_EYE];
    const cv::Point2f &right_eye = face.landmarks[RIGHT_EYE];
    const cv::Point2f &nose = face.landmarks[NOSE];

    constexpr float coverage = 1.4;
    const float scale =
        NORM_FACE_DIM / (coverage * std::max(face.bounds.width, face.bounds.height));
    const cv::Point2f x_axis = scale * (right_eye - left_eye) / cv::norm((right_eye - left_eye));
    const cv::Point2f y_axis{-x_axis.y, x_axis.x};

    float normalize_data[9] = {
        x_axis.x,
        x_axis.y,
        -nose.x * x_axis.x + -nose.y * x_axis.y + static_cast<float>(NORM_FACE_DIM) / 2,
        y_axis.x,
        y_axis.y,
        -nose.x * y_axis.x + -nose.y * y_axis.y + static_cast<float>(NORM_FACE_DIM) / 2,
        0,
        0,
        1};
    const cv::Mat normalize = cv::Mat(2, 3, CV_32F, normalize_data);

    cv::Mat face_image;
    cv::warpAffine(image, face_image, normalize, cv::Size(NORM_FACE_DIM, NORM_FACE_DIM));
    cv::cvtColor(face_image, face_image, cv::COLOR_BGRA2BGR);
    face_image.convertTo(face_image, CV_32FC3, 1.0 / 255.0);

    cv::Mat landmarks_3d;
    run(face_image, landmarks_3d);

    landmarks_3d = landmarks_3d.reshape(LDM_DIMS, LDM_COUNT);
    std::vector<cv::Mat> channels;
    cv::split(landmarks_3d, channels);
    channels.end()[-1].setTo(1);
    cv::merge(channels, landmarks_3d);

    const cv::Mat denormalize =
        cv::Mat(3, 3, CV_32F, normalize_data).inv()(cv::Rect(0, 0, 3, 2)).t();
    landmarks_3d = landmarks_3d.reshape(1, LDM_COUNT);
    cv::gemm(landmarks_3d, denormalize, 1.0, cv::Mat(), 0.0, landmarks_2d);
    landmarks_2d = landmarks_2d.reshape(2, LDM_COUNT);
}

} // namespace lens