#include "facade.h"
#include "mirage.hpp"
#include <iostream>
#include <onnxruntime/core/session/onnxruntime_c_api.h>
#include <opencv2/opencv.hpp>
#include <thread>

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

    std::this_thread::sleep_for(std::chrono::hours::max());

    return 0;
}