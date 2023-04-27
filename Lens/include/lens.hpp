#ifndef MIRAGE_HPP
#define MIRAGE_HPP

#include "facade.h"
#include "filters.hpp"
#include "ml.h"
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

struct point
{
    float x;
    float y;
};

struct frame
{
    int id;
    uint8_t const *pixels;
    size_t channels;
    size_t width;
    size_t height;
};

struct face_extraction
{
    lens::bounds bounds;
    lens::point landmarks[5];
};

struct face
{
    cv::Rect2i bounds;
    cv::Mat landmarks;
    cv::Mat transform;
};

struct face_swap
{
    lens::bounds bounds;
    lens::point landmarks[5];
    cv::Mat &source;
    cv::Mat &destination;
};

class face_pipeline;
typedef std::tuple<face_pipeline *, frame> vp_input;
typedef std::tuple<face_pipeline *, frame, std::vector<face_extraction>> vp_face_extracted;
typedef std::tuple<face_pipeline *, frame, std::vector<face>> vp_face_mesh;
typedef int vp_output;

class face_pipeline
{
public:
    face_pipeline(facade_device *sink, std::string& face_swap_model);
    ~face_pipeline();
    void operator<<(lens::frame frame);
private:
    facade_device *output_device;
    Ort::Session *center_face;
    Ort::Session *face_swap;
    Ort::Session *face_mesh;

    std::unique_ptr<face_swap_model> ml_face_swap;
    std::unique_ptr<gaussian_blur> gaussian_blur;

    oneapi::tbb::concurrent_bounded_queue<lens::frame> input_queue;
    oneapi::tbb::concurrent_bounded_queue<lens::frame> output_queue;
    std::vector<std::thread> thread_pool;
    bool output_ready;

    std::mutex write_mutex;

    void run(int id);

    static vp_face_extracted run_face_extraction(vp_input);
    static vp_face_mesh run_face_mesh(vp_face_extracted);
    static vp_face_mesh run_face_swap(vp_face_mesh);
    static vp_output run_output(vp_face_extracted);
    static void write_callback(lens::face_pipeline *);
};

}

#endif /* MIRAGE_HPP */