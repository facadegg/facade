#include <boost/program_options.hpp>
#include "facade.h"
#include "lens.hpp"
#include <iostream>
#include <opencv2/opencv.hpp>
#include <thread>

namespace po = boost::program_options;

int main(int argc, char **argv)
{
    po::options_description options("Options");
    options.add_options()
            ("dst", po::value<std::string>(), "The name of the video output device")
            ("src", po::value<std::string>(), "The name of the video input device")
            ("frame-rate", po::value<int>(), "The frame rate at which the src should be processed.")
            ("face-swap-model", po::value<std::string>(), "The face swap model to use.");

    po::variables_map vm;

    try
    {
        po::parsed_options parsed = po::command_line_parser(argc, argv)
                .options(options)
                .run();
        po::store(parsed, vm);
        po::notify(vm);
    }
    catch (po::error& e)
    {
        std::cerr << "Invalid command: " << e.what() << std::endl;
        return -1;
    }

    if (!vm.contains("dst"))
    {
        std::cerr << "No --dst provided" << std::endl;
        return -2;
    }
    if (!vm.contains("face-swap-model"))
    {
        std::cerr << "No --face-swap-model provided" << std::endl;
        return -3;
    }

    std::string dst = vm["dst"].as<std::string>();
    std::string face_swap_model = vm["face-swap-model"].as<std::string>();
    int frame_rate = vm.contains("frame-rate") ? vm["frame-rate"].as<int>() : 30;
    int frame_interval = 1000 / frame_rate;

    if (frame_rate < 1 || frame_rate > 60)
    {
        std::cerr << "Unsupported frame-rate " << frame_rate << std::endl;
        return -4;
    }

    facade_device *device;

    facade_init();
    facade_find_device_by_name(dst.c_str(), &device);

    if (!device)
    {
        std::cout << "Failed to locate '" << dst << "' device." << std::endl;
        return -1;
    }

    int id = 0;
    cv::VideoCapture cap(0, cv::VideoCaptureAPIs::CAP_AVFOUNDATION);

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

    lens::face_pipeline pipeline(device, face_swap_model);
    std::chrono::time_point last_read = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < 1000000; i++)
    {
        std::chrono::time_point next_read = last_read + std::chrono::milliseconds(frame_interval);

        cv::Mat cv_frame;
        bool success = cap.read(cv_frame);

        std::chrono::milliseconds wait_for = std::chrono::duration_cast<std::chrono::milliseconds>(next_read - std::chrono::high_resolution_clock::now());
        if (wait_for.count() > 1) {
            std::this_thread::sleep_for(wait_for);
        }

        last_read = next_read;

        if (!success) { // if reading the frame fails, reset the VideoCapture object
            cap.set(cv::CAP_PROP_POS_FRAMES, 0);
            continue;
        }

        size_t width = cv_frame.cols;
        size_t height = cv_frame.rows;
        auto *frame_data = new uint8_t[cv_frame.channels() * width * height * 2];
        memcpy(frame_data, cv_frame.data, cv_frame.channels() * width * height);

        lens::frame next_frame = {
                .id = id++,
                .pixels = frame_data,
                .channels = static_cast<size_t>(cv_frame.channels()),
                .width = width,
                .height = height,
        };

        pipeline << next_frame;
    }

    std::this_thread::sleep_for(std::chrono::hours::max());

    return 0;
}
