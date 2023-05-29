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

static const int NORM_FACE_DIM = 192;
static const int LDM_DIMS = 3;
static const int LDM_COUNT = 468;

static const char *INPUT_TENSOR_NAME = "input_1";
static constexpr size_t INPUT_TENSOR_RANK = 4;
static const int64_t INPUT_TENSOR_SHAPE[INPUT_TENSOR_RANK] = {1, 192, 192, 3};
static const char *OUTPUT_TENSOR_NAME = "conv2d_21";

class face_mesh_impl : public face_mesh
{
  public:
    explicit face_mesh_impl(Ort::Session *);
    ~face_mesh_impl() noexcept override;
    void run(const cv::Mat &face, cv::Mat &landmarks) override;

  private:
    std::unique_ptr<Ort::Session> session;
};

face_mesh_impl::face_mesh_impl(Ort::Session *session) :
    session(session)
{ }

face_mesh_impl::~face_mesh_impl() noexcept { }

void face_mesh_impl::run(const cv::Mat &face, cv::Mat &landmarks)
{
    assert(face.channels() == 3);
    assert(face.rows == NORM_FACE_DIM);
    assert(face.cols == NORM_FACE_DIM);

    Ort::MemoryInfo memory_info("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);
    Ort::Value input_tensor = Ort::Value::CreateTensor<float>(memory_info,
                                                              reinterpret_cast<float *>(face.data),
                                                              face.total() * face.channels(),
                                                              INPUT_TENSOR_SHAPE,
                                                              INPUT_TENSOR_RANK);
    Ort::RunOptions run_options{nullptr};
    std::vector<Ort::Value> output_tensors =
        session->Run(run_options, &INPUT_TENSOR_NAME, &input_tensor, 1, &OUTPUT_TENSOR_NAME, 1);
    Ort::Value &landmarks_tensor = output_tensors[0];
    float *landmarks_ptr = landmarks_tensor.GetTensorMutableData<float>();

    cv::Mat(LDM_DIMS, LDM_COUNT, CV_32F, landmarks_ptr).copyTo(landmarks);
}

std::unique_ptr<face_mesh> face_mesh::build(const fs::path &path)
{
    Ort::Env env(ORT_LOGGING_LEVEL_INFO, "FaceMesh");
    Ort::SessionOptions session_options;

#ifdef APPLE
    OrtSessionOptionsAppendExecutionProvider_CoreML(session_options, COREML_FLAG_USE_NONE);
#endif

    std::string model_path = (path / "FaceMesh.onnx").string();

    return std::unique_ptr<face_mesh>(
        new face_mesh_impl(new Ort::Session(env, model_path.c_str(), session_options)));
}

} // namespace lens
