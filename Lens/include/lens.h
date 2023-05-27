#ifndef LENS_H_B817AF35
#define LENS_H_B817AF35

#include "facade.h"
#include "internal.h"
#include <oneapi/tbb.h>
#include <opencv2/opencv.hpp>
#include <filesystem>
#include <tuple>

#ifdef LENS_FEATURE_ONNX
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>
#endif

extern cv::Mat NORMALIZED_FACIAL_LANDMARKS;

namespace lens
{

struct bounds
{
    float left;
    float top;
    float right;
    float bottom;

    inline float width() const
    {
        return right - left;
    }

    inline float height() const
    {
        return bottom - top;
    }
};

struct frame
{
    int id;
    uint8_t const *pixels;
    size_t channels;
    size_t width;
    size_t height;
};

class face_pipeline;
typedef std::tuple<face_pipeline *, frame> vp_input;
typedef std::tuple<face_pipeline *, frame, std::vector<face_extraction>> vp_face_extracted;
typedef std::tuple<face_pipeline *, frame, std::vector<face>> vp_face_mesh;

class face_pipeline
{
public:
    face_pipeline(facade_device *sink, const std::filesystem::path& root_dir, const std::filesystem::path& face_swap_model);
    ~face_pipeline();
    void operator<<(cv::Mat& image);
private:
    facade_device *output_device;
    double frame_interval_mean;
    size_t frame_counter_read;
    size_t frame_counter_write;

    std::unique_ptr<center_face> center_face;
    std::unique_ptr<face_mesh> face_mesh;
    std::unique_ptr<face_swap> face_swap;

    oneapi::tbb::concurrent_bounded_queue<cv::Mat> input_queue;
    oneapi::tbb::concurrent_bounded_queue<cv::Mat> output_queue;
    std::vector<std::thread> thread_pool;
    bool output_ready;
    std::mutex write_mutex;

    [[noreturn]] void run();
    void run_face_alignment(cv::Mat&, const std::vector<face_extraction>&, std::vector<face>&);
    void run_face_swap(cv::Mat&, const std::vector<face>&, std::function<void(cv::Mat&)>);
    void submit(cv::Mat&);

    void write();

    static cv::Mat umeyama2(const cv::Mat& src, const cv::Mat& dst);
    static void write_stub(face_pipeline *);
};

bool load(const std::string& media, int frame_rate, face_pipeline&);

}

#endif // LENS_H_B817AF35