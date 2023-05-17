#pragma once

#include <opencv2/opencv.hpp>

namespace lens
{

class center_face_model
{
public:
    virtual void run(cv::Mat& in_image, cv::Mat& heatmaps, cv::Mat& scales_x, cv::Mat& scales_y) = 0;
    static std::unique_ptr<center_face_model> build();
};

class face_mesh_model
{
public:
    virtual void run(cv::Mat& in_face, cv::Mat& out_landmarks) = 0;
    static std::unique_ptr<face_mesh_model> build();
};

class face_swap_model
{
public:
    virtual ~face_swap_model();
    virtual void run(cv::Mat& in_face, cv::Mat& out_celebrity_face, cv::Mat& out_celebrity_face_mask) = 0;
    static std::unique_ptr<face_swap_model> build(const std::string& filename);
};

} // namespace lens