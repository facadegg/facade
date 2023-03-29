#ifndef MIRAGE_HPP
#define MIRAGE_HPP

#include "facade.h"
#include <oneapi/tbb.h>
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>
#include <opencv2/opencv.hpp>
#include <tuple>

extern cv::Mat NORMALIZED_FACIAL_LANDMARKS;

enum FacialLandmark {
    LEFT_EYE = 0,
    RIGHT_EYE = 1,
    NOSE = 2,
    LEFT_MOUTH_CORNER = 3,
    RIGHT_MOUTH_CORNER = 4,
    MAX = RIGHT_MOUTH_CORNER,
};

namespace facade
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

struct point
{
    float x;
    float y;
};

struct frame
{
    uint8_t const *pixels;
    size_t channels;
    size_t width;
    size_t height;
};

struct face_extraction
{
    facade::bounds bounds;
    facade::point landmarks[5];
};

struct face
{
    cv::Rect2i bounds;
    cv::Mat landmarks;
    cv::Mat transform;
};

struct face_swap
{
    facade::bounds bounds;
    facade::point landmarks[5];
    cv::Mat &source;
    cv::Mat &destination;
};

class video_pipeline;
typedef std::tuple<video_pipeline *, frame> vp_input;
typedef std::tuple<video_pipeline *, frame, std::vector<face_extraction>> vp_face_extracted;
typedef std::tuple<video_pipeline *, frame, std::vector<face>> vp_face_mesh;
typedef int vp_output;

class pipeline_control_delegate
{
public:
    explicit pipeline_control_delegate(oneapi::tbb::concurrent_queue<facade::frame>& queue);
    std::tuple<video_pipeline *, facade::frame> operator()(oneapi::tbb::flow_control& fc);
    void operator<<(facade::video_pipeline *);
private:
    oneapi::tbb::concurrent_queue<facade::frame>& queue;
    video_pipeline *ptr;
    video_pipeline **ptr_ptr;
};

class video_pipeline
{
public:
    explicit video_pipeline(facade_device *sink);
    ~video_pipeline();
    void operator<<(facade::frame frame);
private:
    facade_device *output_device;
    Ort::Session *center_face;
    Ort::Session *face_swap;
    Ort::Session *face_mesh;

    oneapi::tbb::concurrent_queue<facade::frame> input_queue;
    oneapi::tbb::concurrent_queue<facade::frame> output_queue;
    bool output_ready;

    std::mutex write_mutex;

    oneapi::tbb::flow::graph g;
    facade::pipeline_control_delegate flow_control_delegate;
    oneapi::tbb::flow::input_node<std::tuple<video_pipeline *, frame>> input_node;
    oneapi::tbb::flow::function_node<vp_input, vp_face_extracted> face_extraction_node;
    oneapi::tbb::flow::function_node<vp_face_extracted, int> output_node;

    static vp_face_extracted run_face_extraction(vp_input);
    static vp_face_mesh run_face_mesh(vp_face_extracted);
    static vp_face_mesh run_face_swap(vp_face_mesh);
    static vp_output run_output(vp_face_extracted);
    static void write_callback(facade::video_pipeline *);
};

}

#endif /* MIRAGE_HPP */