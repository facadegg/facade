//
// Created by Shukant Pal on 2/18/23.
//

#include <iostream>
#include <map>

#include "commands.hpp"
#include "facade.h"

std::map<facade_error_code, std::optional<std::string>> codes = {
        {facade_error_none,             "facade_error_none"},
        {facade_error_unknown,          "facade_error_unknown"},
        {facade_error_protocol,         "facade_error_protocol"},
        {facade_error_invalid_type,     "facade_error_invalid_type"},
        {facade_error_invalid_state,    "facade_error_invalid_state"},
        {facade_error_invalid_input,    "facade_error_invalid_input"},
        {facade_error_reader_not_ready, "facade_error_reader_not_ready"},
        {facade_error_writer_not_ready, "facade_error_write_not_ready"},
        {facade_error_not_installed,    "facade_error_not_installed"},
        {facade_error_not_initialized,  "facade_error_not_initialized"},
        {facade_error_not_found,        "facade_error_not_found"}
};

std::string unknown_error = "unknown_error (maybe a future version of libfacade?)";

int command_device_create(boost::program_options::variables_map& vm)
{
    if (!vm.count("type") ||
        !vm.count("name") ||
        !vm.count("width") ||
        !vm.count("height") ||
        !vm.count("frame-rate"))
    {
        std::cout << "facade device create requires --type, --name, --width, --height, --frame-rate" << std::endl;
        return -1;
    }

    std::string type = vm["type"].as<std::string>();
    std::string name = vm["name"].as<std::string>();
    int width = vm["width"].as<int>();
    int height = vm["height"].as<int>();
    int frame_rate = vm["frame-rate"].as<int>();

    if (type != "video")
    {
        std::cout << "Unrecognized type '" << type << "'" << std::endl;
        return -1;
    }

    facade_device_info info = {
            .type = facade_type_video,
            .uid = nullptr,
            .name = name.c_str(),
            .width = (uint32_t) width,
            .height = (uint32_t) height,
            .frame_rate = (uint32_t) frame_rate
    };
    facade_error_code code = facade_create_device(&info);

    if (code != facade_error_none)
    {
        std::cerr << codes[code].value_or(unknown_error) << std::endl;
        return -1;
    }

    return 0;
}

int command_device_edit  (boost::program_options::variables_map& vm)
{
    return -1;
}

int command_device_delete(boost::program_options::variables_map& vm)
{
    return -1;
}

int command_state_import (boost::program_options::variables_map& vm)
{
    return -1;
}

int command_state_export (boost::program_options::variables_map& vm)
{
    return -1;
}