#include <boost/program_options.hpp>
#include "facade.h"
#include "lens.hpp"
#include <iostream>
#include <opencv2/opencv.hpp>
#include <thread>

namespace po = boost::program_options;

int main(int argc, char **argv)
{
    std::cout << "Lens is starting..." << std::endl;

    po::options_description options("Options");
    options.add_options()
            ("dst", po::value<std::string>(), "The name of the video output device")
            ("src", po::value<std::string>(), "The name of the video input device")
            ("frame-rate", po::value<int>(), "The frame rate at which the src should be processed.")
            ("face-swap-model", po::value<std::string>(), "The face swap model to use.")
            ("root-dir", po::value<std::string>(), "The directory in which ML models are stored");

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
    if (!vm.contains("root-dir"))
    {
        std::cerr << "No --root-dir provided" << std::endl;
        return -4;
    }

    std::string src = vm.contains("src") ? vm["src"].as<std::string>() : "";
    std::string dst = vm["dst"].as<std::string>();
    std::string root_dir = vm["root-dir"].as<std::string>();
    std::string face_swap_model = vm["face-swap-model"].as<std::string>();
    int frame_rate = vm.contains("frame-rate") ? vm["frame-rate"].as<int>() : 30;
    int frame_interval = 1000 / frame_rate;

    if (frame_rate < 1 || frame_rate > 60)
    {
        std::cerr << "Unsupported frame-rate " << frame_rate << std::endl;
        return -4;
    }

    facade_device *device = nullptr;

    facade_init();
    facade_find_device_by_name(dst.c_str(), &device);

    if (!device)
    {
        facade_find_device_by_uid(dst.c_str(), &device);
    }

    if (!device)
    {
        std::cout << "Failed to locate '" << dst << "' device." << std::endl;
        return -1;
    }

    int id = 0;
    cv::VideoCapture cap(1, cv::VideoCaptureAPIs::CAP_AVFOUNDATION);

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

    std::cout << "Starting face pipeline!" << std::endl;

    try {
        lens::face_pipeline pipeline(device, root_dir, std::filesystem::path(face_swap_model));

        if (lens::load(src, frame_rate, pipeline)) {
            std::this_thread::sleep_for(std::chrono::hours::max());
        } else {
            std::cout << "Failed to locate source file or device" << std::endl;
        }
    } catch (std::exception& e) {
        std::cout << e.what() << std::endl;
    }

    return 0;
}
