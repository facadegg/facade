#pragma once

#include <filesystem>
#include <tuple>
#include <opencv2/opencv.hpp>
#include "filters.hpp"

namespace lens
{

struct face_extraction
{
    cv::Rect2f bounds;
    cv::Point2f landmarks[5];
};

struct face
{
    cv::Rect2i bounds;
    cv::Mat landmarks;
    cv::Mat transform;
};

class center_face
{
public:
    virtual ~center_face() noexcept;
    virtual void run(const cv::Mat& image,
                     cv::Mat& heatmap,
                     std::tuple<cv::Mat, cv::Mat>& scales,
                     std::tuple<cv::Mat, cv::Mat>& offsets,
                     std::vector<cv::Mat>& landmarks) = 0;
    void run(const cv::Mat& image, std::vector<face_extraction>& extractions);
    static std::unique_ptr<center_face> build(const std::string& path);
};

class face_mesh
{
public:
    virtual ~face_mesh() noexcept;
    virtual void run(const cv::Mat& face, cv::Mat& landmarks) = 0;
    static std::unique_ptr<face_mesh> build(const std::string& path);
};

class face_swap_model
{
public:
    face_swap_model();
    virtual ~face_swap_model();
    virtual void run(cv::Mat& in_face, cv::Mat& out_celebrity_face, cv::Mat& out_celebrity_face_mask) = 0;
    virtual void composite(cv::Mat& dst,
                           const face& extraction,
                           cv::Mat& face,
                           cv::Mat& out_celeb_face,
                           cv::Mat& out_celeb_face_mask);
    static std::unique_ptr<face_swap_model> build(const std::filesystem::path& path);

protected:
    std::unique_ptr<gaussian_blur> gaussian_blur;

    cv::Mat erode_and_blur(cv::Mat& image, int erode, int blur);
    cv::Mat color_transfer(cv::Mat& src, cv::Mat& like);
};

} // namespace lens