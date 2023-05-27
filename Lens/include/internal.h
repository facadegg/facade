//
// Created by Shukant Pal on 5/26/23.
//

#pragma once

#include <filesystem>
#include <oneapi/tbb.h>
#include <opencv2/opencv.hpp>
#include <tuple>

namespace lens
{

#pragma mark - Image Processing

class filter
{
public:
    virtual void run(cv::Mat& in, cv::Mat& out) = 0;
};

class gaussian_blur : public filter
{
public:
    virtual ~gaussian_blur() noexcept;
    static std::unique_ptr<gaussian_blur> build();
    virtual double get_radius() = 0;
    virtual void set_radius(double) = 0;
};

#pragma mark - Model Execution

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

struct face2face
{
    cv::Mat src_face;
    cv::Mat dst_face;
    cv::Mat mask;

    face2face() :
            src_face(),
            dst_face(cv::Mat(224, 224, CV_32FC3)),
            mask(cv::Mat(224, 224, CV_32FC1))
    { }
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

class face_swap
{
public:
    face_swap();
    virtual ~face_swap();
    virtual face2face* run(cv::Mat& in_face) = 0;
    virtual void composite(cv::Mat& dst,
                           const face& extraction,
                           face2face **,
                           const std::function<void(cv::Mat&)> callback);

    static std::unique_ptr<face_swap> build(const std::filesystem::path& model_path,
                                            const std::filesystem::path& root_dir);
    static cv::Mat color_transfer(cv::Mat& src, cv::Mat& like);
protected:
    std::unique_ptr<gaussian_blur> gaussian_blur;
    oneapi::tbb::concurrent_queue<face2face*> face2face_pool;

    cv::Mat erode_and_blur(cv::Mat& image, int erode, int blur);
};

}