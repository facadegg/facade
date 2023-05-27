//
// Created by Shukant Pal on 5/26/23.
//

#include <onnxruntime/core/providers/coreml/coreml_provider_factory.h>
#include <onnxruntime/core/session/onnxruntime_c_api.h>
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>

#include "internal.h"

namespace fs = std::filesystem;

namespace lens
{

static const size_t EXPECTED_ROWS = 480;
static const size_t EXPECTED_COLS = 640;
static const size_t EXPECTED_CHANNELS = 3;

static const char *INPUT_NAME = "input.1";
static constexpr size_t INPUT_TENSOR_RANK = 4;
static const int64_t INPUT_TENSOR_SHAPE[INPUT_TENSOR_RANK] = {
    1, EXPECTED_ROWS, EXPECTED_COLS, EXPECTED_CHANNELS};

static constexpr size_t OUTPUT_TENSOR_COUNT = 4;
static const char *OUTPUT_TENSOR_NAMES[OUTPUT_TENSOR_COUNT] = {"537", "538", "539", "540"};

static const int OUT_ROWS = EXPECTED_ROWS / 4;
static const int OUT_COLS = EXPECTED_COLS / 4;
static const int OUT_LANDMARKS = 5;

class center_face_impl : public center_face
{
  public:
    explicit center_face_impl(Ort::Session *);
    ~center_face_impl() noexcept override;
    void run(const cv::Mat &image,
             cv::Mat &heatmap,
             std::tuple<cv::Mat, cv::Mat> &scales,
             std::tuple<cv::Mat, cv::Mat> &offsets,
             std::vector<cv::Mat> &landmarks) override;

  private:
    std::unique_ptr<Ort::Session> session;
};

center_face_impl::center_face_impl(Ort::Session *session) :
    session(session)
{ }

center_face_impl::~center_face_impl() noexcept { }

void center_face_impl::run(const cv::Mat &image,
                           cv::Mat &heatmap,
                           std::tuple<cv::Mat, cv::Mat> &scales,
                           std::tuple<cv::Mat, cv::Mat> &offsets,
                           std::vector<cv::Mat> &landmarks)
{
    assert(image.cols == EXPECTED_COLS);
    assert(image.rows == EXPECTED_ROWS);
    assert(image.channels() == EXPECTED_CHANNELS);
    assert(landmarks.size() == OUT_LANDMARKS * 2);

    size_t elems = image.total() * image.channels();

    Ort::MemoryInfo memory_info("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);
    Ort::Value input_tensor = Ort::Value::CreateTensor<float>(memory_info,
                                                              reinterpret_cast<float *>(image.data),
                                                              elems,
                                                              INPUT_TENSOR_SHAPE,
                                                              INPUT_TENSOR_RANK);

    Ort::RunOptions run_options{nullptr};
    std::vector<Ort::Value> output_tensors = session->Run(
        run_options, &INPUT_NAME, &input_tensor, 1, OUTPUT_TENSOR_NAMES, OUTPUT_TENSOR_COUNT);

    Ort::Value &heatmaps_tensor = output_tensors[0];
    Ort::Value &scales_tensor = output_tensors[1];
    Ort::Value &offsets_tensor = output_tensors[2];
    Ort::Value &landmarks_tensor = output_tensors[3];
    std::vector<int64_t> heatmaps_shape = heatmaps_tensor.GetTensorTypeAndShapeInfo().GetShape();
    size_t out_rows = heatmaps_shape[2];
    size_t out_cols = heatmaps_shape[3];

    assert(out_rows == OUT_ROWS);
    assert(out_cols == OUT_COLS);

    float *heatmap_ptr = heatmaps_tensor.GetTensorMutableData<float>();
    float *scales_ptr = scales_tensor.GetTensorMutableData<float>();
    float *offsets_ptr = offsets_tensor.GetTensorMutableData<float>();
    float *landmarks_ptr = landmarks_tensor.GetTensorMutableData<float>();

    cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, heatmap_ptr).copyTo(heatmap);
    cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, scales_ptr).copyTo(std::get<0>(scales));
    cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, scales_ptr + OUT_ROWS * OUT_COLS)
        .copyTo(std::get<1>(scales));
    cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, offsets_ptr).copyTo(std::get<0>(offsets));
    cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, offsets_ptr + OUT_ROWS * OUT_COLS)
        .copyTo(std::get<1>(offsets));

    for (int i = 0; i < OUT_LANDMARKS * 2; i++)
    {
        cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, landmarks_ptr + OUT_ROWS * OUT_COLS * i)
            .copyTo(landmarks[i]);
    }
}

std::unique_ptr<center_face> center_face::build(const std::string &path)
{
    Ort::Env env(ORT_LOGGING_LEVEL_INFO, "CenterFace");
    Ort::SessionOptions session_options;

#ifdef APPLE
    OrtSessionOptionsAppendExecutionProvider_CoreML(session_options, COREML_FLAG_USE_NONE);
#endif

    return std::unique_ptr<center_face>(
        new center_face_impl(new Ort::Session(env, path.c_str(), session_options)));
}

} // namespace lens