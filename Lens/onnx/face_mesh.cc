//
// Created by Shukant Pal on 5/26/23.
//

#include <onnxruntime/core/session/onnxruntime_c_api.h>
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>
#include <onnxruntime/core/providers/coreml/coreml_provider_factory.h>

#include "internal.h"

namespace lens
{

static const int NORM_FACE_DIM = 192;
static const int LDM_DIMS = 3;
static const int LDM_COUNT = 468;

static const char *INPUT_TENSOR_NAME = "input_1";
static constexpr size_t INPUT_TENSOR_RANK = 4;
static const int64_t INPUT_TENSOR_SHAPE[INPUT_TENSOR_RANK] = { 1, 192, 192, 3 };
static const char *OUTPUT_TENSOR_NAME = "conv2d_21";

class face_mesh_impl : public face_mesh
{
public:
    explicit face_mesh_impl(Ort::Session*);
    ~face_mesh_impl() noexcept override;
    void run(const cv::Mat& face, cv::Mat& landmarks) override;
private:
    std::unique_ptr<Ort::Session> session;
};

face_mesh::~face_mesh() noexcept = default;

face_mesh_impl::face_mesh_impl(Ort::Session* session) :
    session(session)
{ }

face_mesh_impl::~face_mesh_impl() noexcept
{ }

void face_mesh_impl::run(const cv::Mat& face, cv::Mat& landmarks)
{
    assert(face.channels() == 4);

    cv::Mat resized_face;
    cv::resize(face, resized_face, cv::Size(NORM_FACE_DIM, NORM_FACE_DIM));
    cv::cvtColor(resized_face, resized_face, cv::COLOR_BGRA2BGR);
    resized_face.convertTo(resized_face, CV_32FC3, 1.0 / 255.0);

    Ort::MemoryInfo memory_info("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);
    Ort::Value input_tensor = Ort::Value::CreateTensor<float>(memory_info,
                                                              reinterpret_cast<float *>(resized_face.data),
                                                              resized_face.total() * resized_face.channels(),
                                                              INPUT_TENSOR_SHAPE,
                                                              INPUT_TENSOR_RANK);
    Ort::RunOptions run_options{nullptr};
    std::vector<Ort::Value> output_tensors = session->Run(run_options,
                                                          &INPUT_TENSOR_NAME,
                                                          &input_tensor,
                                                          1,
                                                          &OUTPUT_TENSOR_NAME,
                                                          1);
    Ort::Value& landmarks_tensor = output_tensors[0];
    float *landmarks_ptr = landmarks_tensor.GetTensorMutableData<float>();

    cv::Mat(LDM_DIMS, LDM_COUNT, CV_32F, landmarks_ptr).copyTo(landmarks);
}

std::unique_ptr<face_mesh> face_mesh::build(const std::string& path)
{
    Ort::Env env(ORT_LOGGING_LEVEL_INFO, "FaceMesh");
    Ort::SessionOptions session_options;

#ifdef APPLE
    OrtSessionOptionsAppendExecutionProvider_CoreML(session_options, COREML_FLAG_USE_NONE);
#endif

    return std::unique_ptr<face_mesh>(new face_mesh_impl(new Ort::Session(env, path.c_str(), session_options)));
}

} // namespace lens
