#pragma once

#include <opencv2/opencv.hpp>

namespace lens
{

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

} // namespace lens