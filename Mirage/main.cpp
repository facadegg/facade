#include "facade.h"
#include "mirage.hpp"
#include <iostream>
#include <onnxruntime/core/session/onnxruntime_c_api.h>
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>
#include <onnxruntime/core/providers/coreml/coreml_provider_factory.h>
#include <opencv2/opencv.hpp>
#include <thread>

struct context {
    cv::VideoCapture& input;
    facade_device *output;
    uint8_t *image_buffer;

    Ort::Env& env;
    Ort::Session& session;
    Ort::Allocator& allocator;
    std::vector<int64_t> tensor_shape;
};

std::vector<float> input_data(16 * 640 * 640 * 3);
cv::Mat frame;

char *OUTPUT_NAMES[4] = {
        "537",
        "538",
        "539",
        "540"
};

//void process_frame(void *c)
//{
//    auto *context = (struct context *) c;
//    cv::VideoCapture& input = context->input;
//    facade_device *output = context->output;
//
//    input >> frame;
//
//    static cv::Mat p640;
//    static cv::Size target_size(640, 480);
//    std::cout << "HERE1" <<  frame.cols << std::endl;
//    cv::resize(frame, p640, target_size);
//    std::cout << "HERE" << std::endl;
//
//    static cv::Mat p640f;
//    p640.convertTo(p640f, CV_32FC3, 1.0);
//    static std::vector<cv::Mat> channels(3);
//    cv::split(p640f, channels);
//    int pixel_idx = 0;
//
//    for (int c = 0; c < 3; ++c) {
//        for (int i = 0; i < target_size.height; ++i) {
//            for (int j = 0; j < target_size.width; ++j) {
//                input_data[pixel_idx++] = channels[c].at<float>(i, j);
//            }
//        }
//    }
//
//    Ort::MemoryInfo memory_info("Cpu", OrtDeviceAllocator, 0, OrtMemTypeDefault);
//    Ort::Value input_tensor = Ort::Value::CreateTensor<float>(memory_info, input_data.data(), input_data.size(), context->tensor_shape.data(), context->tensor_shape.size());
//    Ort::AllocatedStringPtr input_name = context->center_face.GetInputNameAllocated(0, context->allocator);
//    Ort::AllocatedStringPtr output_name = context->center_face.GetOutputNameAllocated(0, context->allocator);
//    char *input_name_ptr = input_name.get();
//
//    Ort::RunOptions run_options{nullptr};
//
//    auto start_time = std::chrono::high_resolution_clock::now();
//    std::vector<Ort::Value> output_tensors = context->center_face.Run(run_options, &input_name_ptr, &input_tensor, 1, OUTPUT_NAMES, 4);
//    auto end_time = std::chrono::high_resolution_clock::now();
//
//    std::cout << " TIME WAS " <<  std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count() << std::endl;
//
//    Ort::Value& heatmaps_tensor = output_tensors[0];
//    Ort::Value& scales_tensor = output_tensors[1];
//    Ort::Value& offsets_tensor = output_tensors[2];
//
//    const float* heatmaps = heatmaps_tensor.GetTensorMutableData<float>();
//    const float* scales = scales_tensor.GetTensorMutableData<float>();
//    const float* offsets = offsets_tensor.GetTensorMutableData<float>();
//    std::vector<int64_t> output_shape = heatmaps_tensor.GetTensorTypeAndShapeInfo().GetShape();
//
//    int bx = 0, by = 0, bw = 0, bh = 0;
//    float max_probability = 0.35;
//    bool done = false;
//
//    int output_rows = output_shape[2];
//    int output_columns = output_shape[3];
//
//    // Print the output tensor values
//    for (int y = 0; y < output_rows && !done; y++) {
//        for (int x = 0; x < output_columns && !done; x++) {
//            int index = y * output_columns + x;
//            float probability = heatmaps[index];
//
//            if (probability > max_probability) {
//                max_probability = probability;
//                std::cout << "FOUND PROBABILITY" << std::endl;
//
//                bh = std::exp(scales[index]) * 4.0 * 1080.0 / 480.0;
//                bw = std::exp(scales[output_rows * output_columns + index]) * 4.0 * 1920.0 / 640.0;
//                by = (y + 0.5 + offsets[index]) * 4.0 * 1080.0 / 480.0;
//                bx = (x + 0.5 + offsets[output_rows * output_columns + index]) * 4.0 * 1920.0 / 640.0;
////                done = true;
//            }
//        }
//    }
//
//    for (int i = 0; i < frame.rows; i++)
//    {
//        for (int j = 0; j < frame.cols; j++)
//        {
//            int x = j;
//            int y = i;
//            cv::Vec3b bgraPixel = frame.at<cv::Vec3b>(y, x); // cv::Vec4b(x, y, 0, 1);
//
//            if (std::abs(x - bx + bw / 2) < 4 || std::abs(y - by + bh / 2) < 4 || std::abs(x - bx - bw / 2) < 4 || std::abs(y - by - bh / 2) < 4) {
//                bgraPixel[0] = 255;
//                bgraPixel[1] = 0;
//                bgraPixel[2] = 0;
//            }
//
//            auto o = 4 * (i * frame.cols + j);
//            context->image_buffer[o] = bgraPixel[0];
//            context->image_buffer[o + 1] = bgraPixel[1];
//            context->image_buffer[o + 2] = bgraPixel[2];
//            context->image_buffer[o + 3] = 255;
//        }
//    }
//
//
//    std::cout << "here " << frame.channels() << std::endl;
//
//    facade_write_frame(output, context->image_buffer,4 * output->width * output->height);
//}

int main(int argc, char **argv)
{
    facade_device *device;

    facade_init();
    facade_find_device_by_name("Deepfake", &device);

    if (!device)
    {
        std::cout << "Failed to locate 'Deepfake'" << std::endl;
        return -1;
    }

    cv::VideoCapture cap(1);

    if (!cap.isOpened())
    {
        std::cout << "Failed to open default camera" << std::endl;
        return -1;
    }
    else
    {
        int width = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
        int height = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));

        std::cout << width  << "x" << height << std::endl;

        if (width != device->width || height != device->height)
        {
            std::cout << "Dimensions mismatch, device output should be " << device->width << "x" << device->height << std::endl;
            return -2;
        }
    }

    facade::video_pipeline pipeline(device);

    for (int i = 0; i < 1000000; i++)
    {
        cv::Mat cv_frame;
        bool success = cap.read(cv_frame);

        if (!success) { // if reading the frame fails, reset the VideoCapture object
            cap.set(cv::CAP_PROP_POS_FRAMES, 0);
            continue;
        }

        size_t width = cv_frame.cols;
        size_t height = cv_frame.rows;
        auto *frame_data = new uint8_t[cv_frame.channels() * width * height];
        memcpy(frame_data, cv_frame.data, cv_frame.channels() * width * height);

        facade::frame next_frame = {
                .pixels = frame_data,
                .channels = static_cast<size_t>(cv_frame.channels()),
                .width = width,
                .height = height,
        };

        pipeline << next_frame;
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }

//    Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "YOLOv8");
//    Ort::SessionOptions session_options;
//    OrtSessionOptionsAppendExecutionProvider_CoreML(session_options, 0);
//    Ort::Session center_face(env, "/Users/shukantpal/Downloads/CenterFace640x480.onnx", session_options);
//    Ort::AllocatorWithDefaultOptions allocator;
//
//    for (auto i = 0; i < center_face.GetOutputCount(); i++) {
//        auto inputName = center_face.GetOutputNameAllocated(i, allocator);
//        std::cout << inputName << std::endl;
//        Ort::TypeInfo type_info = center_face.GetOutputTypeInfo(i);
//        std::cout << type_info.GetONNXType() << std::endl;
//
//        Ort::ConstTensorTypeAndShapeInfo tensor_info = type_info.GetTensorTypeAndShapeInfo();
//        std::vector<int64_t> tensor_shape = tensor_info.GetShape();
//        std::vector<int64_t> tensor_size = tensor_info.GetShape();
//        std::cout << tensor_size[2] << std::endl;
//    }
//
//    Ort::TypeInfo image_type_info = center_face.GetInputTypeInfo(0);
//    Ort::ConstTensorTypeAndShapeInfo  tensor_info = image_type_info.GetTensorTypeAndShapeInfo();
//    std::vector<int64_t> tensor_shape = tensor_info.GetShape();
//
//    context context = {
//           .input = cap,
//           .output = device,
//           .image_buffer = new uint8_t[4 * device->width * device->height],
//           .env = env,
//           .center_face = center_face,
//           .allocator = reinterpret_cast<Ort::Allocator &>(allocator),
//           .tensor_shape = tensor_shape
//    };
//    facade_write_open(device);
//    facade_write_callback(device, process_frame, &context);
//    process_frame(&context);

    std::this_thread::sleep_for(std::chrono::hours::max());

    return 0;
}