//
// Created by Shukant Pal on 4/1/23.
//

#include <onnxruntime/core/session/onnxruntime_c_api.h>
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>
#include <onnxruntime/core/providers/coreml/coreml_provider_factory.h>

int main(int argc, char **argv)
{
    Ort::Env env(ORT_LOGGING_LEVEL_VERBOSE, "Bryan_Greynolds");
    Ort::SessionOptions session_options;
    session_options.EnableProfiling("profile");
    OrtSessionOptionsAppendExecutionProvider_CoreML(session_options, COREML_FLAG_USE_NONE);
    Ort::Session session(env, "/opt/facade/Bryan_Greynolds.onnx", session_options);

    std::unique_ptr<float> data(new float[224 * 224 * 3]);
    const int64_t input_shape[4] = {1,224,224,3};
    Ort::Value input = Ort::Value::CreateTensor<float>(Ort::MemoryInfo("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault),
                                                       data.get(),
                                                       224 * 224 * 3,
                                                       input_shape,
                                                       4);
    const char *input_names[1] = {"in_face:0"};
    const char *output_names[3] = {
            "out_face_mask:0",
            "out_celeb_face:0",
            "out_celeb_face_mask:0"
    };

    Ort::RunOptions run_options;

    for (int i = 0; i < 10; i++)
        std::vector<Ort::Value> outputs = session.Run(run_options, input_names, &input, 1, output_names, 3);


}