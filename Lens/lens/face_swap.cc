//
// Created by Shukant Pal on 5/21/23.
//

#include "internal.h"

namespace lens
{

face_swap::face_swap() :
    gaussian_blur(gaussian_blur::build()),
    face2face_pool()
{ }

void face_swap::composite(cv::Mat& dst, const face& extraction, face2face **job, const std::function<void(cv::Mat&)> callback)
{
#ifndef DEBUG_FEATURE_FACE_SWAP_WITH_NO_COMPOSITE
    cv::Mat& face = (*job)->src_face;
    cv::Mat& out_celeb_face = (*job)->dst_face;
    cv::Mat& out_celeb_face_mask = (*job)->mask;

    out_celeb_face_mask = erode_and_blur(out_celeb_face_mask, 5, 25);
    cv::cvtColor(out_celeb_face_mask, out_celeb_face_mask, cv::COLOR_GRAY2RGB);

    out_celeb_face = color_transfer(out_celeb_face, face);

    cv::multiply(out_celeb_face, cv::Scalar(255, 255, 255), out_celeb_face);
    cv::multiply(out_celeb_face, out_celeb_face_mask, out_celeb_face);

    out_celeb_face_mask = cv::Scalar(1, 1, 1) - out_celeb_face_mask;

    const cv::Mat backwards_transform = extraction.transform.inv()(cv::Rect(0, 0, 3, 2));

    cv::Mat alpha_mask;
    cv::warpAffine(out_celeb_face_mask, alpha_mask,
                   backwards_transform,
                   cv::Size(dst.cols, dst.rows),
                   cv::INTER_LINEAR,
                   cv::BORDER_CONSTANT,
                   cv::Scalar(1, 1, 1));
    cv::cvtColor(alpha_mask, alpha_mask, cv::COLOR_BGR2BGRA);
    cv::multiply(dst, alpha_mask, dst, 1, CV_8UC3);

    alpha_mask = cv::Mat();
    cv::warpAffine(out_celeb_face, alpha_mask,
                   backwards_transform,
                   cv::Size(dst.cols, dst.rows));

    cv::cvtColor(alpha_mask, alpha_mask, cv::COLOR_BGR2BGRA);
    dst += alpha_mask;
#endif

    face2face_pool.push(*job);
    *job = nullptr;

    callback(dst);
}

cv::Mat face_swap::erode_and_blur(cv::Mat& img, int erode, int blur)
{
    cv::Mat out;
    cv::copyMakeBorder(img, out, img.rows, img.rows, img.cols, img.cols, cv::BORDER_CONSTANT);

    if (erode > 0) {
        cv::Mat el = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3));
        int iterations = std::max(1, erode / 2);
        cv::erode(out, out, el, cv::Point(-1, -1), iterations);
    } else if (erode < 0) {
        cv::Mat el = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3));
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
        gaussian_blur->set_radius(sigma);
        gaussian_blur->run(out, out);
    }

    out = out(cv::Range(img.rows, out.rows - img.rows),
              cv::Range(img.cols, out.cols - img.cols));

    return out;
}

cv::Mat face_swap::color_transfer(cv::Mat &src, cv::Mat &like) {
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

} // namespace lens