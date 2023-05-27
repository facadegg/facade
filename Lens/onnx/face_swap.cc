//
// Created by Shukant Pal on 5/26/23.
//

#include <onnxruntime/core/session/onnxruntime_c_api.h>
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>
#include <onnxruntime/core/providers/coreml/coreml_provider_factory.h>

#include "internal.h"

namespace fs = std::filesystem;

namespace lens
{

static constexpr size_t SWAP_DIM = 224;

static constexpr size_t INPUT_TENSOR_RANK = 4;
static const int64_t INPUT_TENSOR_SHAPE[INPUT_TENSOR_RANK] = { 1, SWAP_DIM, SWAP_DIM, 3 };
static const char* INPUT_TENSOR_NAME = "in_face:0";

static constexpr size_t OUTPUT_TENSOR_COUNT = 2;
static const char* OUTPUT_TENSOR_NAMES[OUTPUT_TENSOR_COUNT] = {
        "out_celeb_face:0",
        "out_celeb_face_mask:0",
};

class face_swap_impl : public face_swap
{
public:
    explicit face_swap_impl(Ort::Session*);
    ~face_swap_impl() noexcept override;
    face2face* run(cv::Mat&) override;
private:
    std::unique_ptr<Ort::Session> session;
};

face_swap::~face_swap() = default;

face_swap_impl::face_swap_impl(Ort::Session *session) :
    session(session)
{ }

face_swap_impl::~face_swap_impl() noexcept
{ }

face2face* face_swap_impl::run(cv::Mat &in_face)
{
    face2face* result = nullptr;
    if (!face2face_pool.try_pop(result))
        result = new face2face();

    Ort::MemoryInfo memory_info("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);
    Ort::Value input_tensor = Ort::Value::CreateTensor<float>(memory_info,
                                                              reinterpret_cast<float *>(in_face.data),
                                                              SWAP_DIM * SWAP_DIM * 3,
                                                              INPUT_TENSOR_SHAPE,
                                                              INPUT_TENSOR_RANK);

    Ort::RunOptions run_options{nullptr};
    std::vector<Ort::Value> output_tensors = session->Run(run_options,
                                                          &INPUT_TENSOR_NAME,
                                                          &input_tensor,
                                                          1,
                                                          OUTPUT_TENSOR_NAMES,
                                                          OUTPUT_TENSOR_COUNT);
    Ort::Value& out_celeb_face_tensor = output_tensors[0];
    Ort::Value& out_celeb_face_mask_tensor = output_tensors[1];

    float* out_celeb_face_ptr = out_celeb_face_tensor.GetTensorMutableData<float>();
    float* out_celeb_face_mask_ptr = out_celeb_face_mask_tensor.GetTensorMutableData<float>();

    cv::Mat(SWAP_DIM, SWAP_DIM, CV_32FC3, out_celeb_face_ptr).copyTo(result->dst_face);
    cv::Mat(224, 224, CV_32FC1, out_celeb_face_mask_ptr).copyTo(result->mask);

    return result;
}

std::unique_ptr<face_swap> face_swap::build(const fs::path& path, const fs::path& _)
{
    Ort::Env env(ORT_LOGGING_LEVEL_INFO, "FaceSwap");
    Ort::SessionOptions session_options;

#ifdef APPLE
    OrtSessionOptionsAppendExecutionProvider_CoreML(session_options, COREML_FLAG_USE_NONE);
#endif

    std::string path_str = path.string();

    return std::unique_ptr<face_swap>(new face_swap_impl(new Ort::Session(env, path_str.c_str(), session_options)));
}


}