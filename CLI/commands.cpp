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
std::string empty;

#define GUARD(condition, message)           \
    if ( condition )                        \
    {                                       \
        std::cerr << message << std::endl;  \
        return -1;                          \
    }

#define WARN(condition, message)            \
    if ( condition )                        \
    {                                       \
        std::cerr << message << std::endl;  \
    }

inline void print_xml(facade_device_info *info, std::string& i1 = empty)
{
    std::string i2 = i1 + "    ";
    std::cout << i1 << "<video>"                                            << std::endl
              << i2 << "<uid>" << info->uid << "</uid>"                     << std::endl
              << i2 << "<name>" << info->name << "</name>"                  << std::endl
              << i2 << "<width>" << info->width << "</width>"               << std::endl
              << i2 << "<height>" << info->height << "</height>"            << std::endl
              << i2 << "<frameRate>" << info->frame_rate << "</frameRate>"  << std::endl
              << i1 << "</video>"                                           << std::endl;
}

inline void print_xml(facade_device *device, std::string& i1 = empty)
{
    std::string i2 = i1 + "    ";
    std::cout << i1 << "<video>"                                            << std::endl
              << i2 << "<uid>" << device->uid << "</uid>"                   << std::endl
              << i2 << "<name>" << device->name << "</name>"                << std::endl
              << i2 << "<width>" << device->width << "</width>"             << std::endl
              << i2 << "<height>" << device->height << "</height>"          << std::endl
              << i2 << "<frameRate>" << device->frame_rate << "</frameRate>"<< std::endl
              << i1 << "</video>"                                           << std::endl;
}

inline int with(facade_error_code code)
{
    if (code != facade_error_none)
    {
        std::cerr << codes[code].value_or(unknown_error) << std::endl;
        return -1;
    }

    return 0;
}

int command_device_create(boost::program_options::variables_map& vm)
{
    GUARD(!vm.count("type") ||
          !vm.count("name") ||
          !vm.count("width") ||
          !vm.count("height") ||
          !vm.count("frame-rate"),
          "'facade device create' requires --type, --name, --width, --height, --frame-rate")
    WARN(vm.count("uid"), "Warning: --uid is ignored when creating device!")

    std::string type = vm["type"].as<std::string>();
    std::string name = vm["name"].as<std::string>();

    if (type != "video")
    {
        std::cout << "Unrecognized type '" << type << "'" << std::endl;
        return -1;
    }

    facade_device_info info = {
            .type = facade_device_type_video,
            .uid = nullptr,
            .name = name.c_str(),
            .width = (uint32_t) vm["width"].as<int>(),
            .height = (uint32_t) vm["height"].as<int>(),
            .frame_rate = (uint32_t) vm["frame-rate"].as<int>()
    };
    facade_error_code code = facade_create_device(&info);

    return with(code);
}

void command_device_edit_on_done(void *context)
{
    facade_device *device = (facade_device *) context;

    print_xml(device);
    facade_dispose_device(&device);
}

int command_device_edit(boost::program_options::variables_map& vm)
{
    GUARD(!vm.count("uid"), "'facade device edit' requires --uid")
    WARN(vm.count("type"), "Warning: --type is ignored when editing device.")
    WARN(vm.count("name"), "Warning: --name has no effect on macOS")

    std::string uid = vm["uid"].as<std::string>();
    facade_device *device = nullptr;
    facade_error_code code = facade_find_device_by_uid(uid.c_str(), &device);

    if (code != facade_error_none || device == nullptr)
    {
        std::cerr << "Failed to find device '" << uid
                  << "' (" << codes[code].value_or(unknown_error) << ") " << std::endl;
        return -1;
    }

    GUARD(device->type != facade_device_type_video, "CLI only supports video devices!")
    GUARD(!vm.count("width") &&
          !vm.count("height") &&
          !vm.count("frame-rate"),
          "At least one of --width, --height, --frame-rate must be provided to edit device")

    facade_on_device_changed(device, command_device_edit_on_done, device);

    facade_device_info edits = {
            .next = nullptr,
            .type = facade_device_type_video,
            .uid = nullptr,
            .name = nullptr,
            .width = vm.count("width") ? (uint32_t) vm["width"].as<int>() : 0,
            .height = vm.count("height") ? (uint32_t) vm["height"].as<int>() : 0,
            .frame_rate = vm.count("frame-rate") ? (uint32_t) vm["frame-rate"].as<int>() : 0,
    };
    code = facade_edit_device(uid.c_str(), &edits);

    return with(code);
}

int command_device_delete(boost::program_options::variables_map& vm)
{
    GUARD(!vm.count("uid"), "'facade device delete' requires --uid")

    std::string uid = vm["uid"].as<std::string>();
    facade_error_code code = facade_delete_device(uid.c_str());

    return with(code);
}

int command_device_find(boost::program_options::variables_map& vm)
{
    GUARD(!vm.count("uid") &&
          !vm.count("name") &&
          !vm.count("type"),
          "'facade device find' requires at least one filter --uid, --name, or --type")

    std::string uid = vm.count("uid") ? vm["uid"].as<std::string>() : "";
    std::string type = vm.count("video") ? vm["type"].as<std::string>() : "";
    std::string name = vm.count("name") ? vm["name"].as<std::string>() : "";

    facade_state *state = nullptr;
    facade_error_code code = facade_read_state(&state);

    if (state != nullptr)
    {
        if (state->devices != nullptr)
        {
            facade_device_info *info = state->devices;

            do
            {
                if ((uid.empty() || strcmp(uid.c_str(), info->uid) == 0) &&
                    (type.empty() || (type == "video" && info->type == facade_device_type_video)) &&
                    (name.empty() || strcmp(name.c_str(), info->name) == 0))
                {
                    print_xml(info);
                }
            } while(info != state->devices);
        }

        facade_dispose_state(&state);
    }

    return with(code);
}

int command_state_import(boost::program_options::variables_map& vm)
{
    std::cout << vm["command"].as<std::string>() << std::endl;
    GUARD(true, "This has not been implemented! Contact support@facade.dev if you need this.")
}

int command_state_export(boost::program_options::variables_map& vm)
{
    GUARD(vm.count("output") && vm["output"].as<std::string>() != "xml", "--output must be 'xml'")

    facade_state *state = nullptr;
    facade_error_code code = facade_read_state(&state);

    if (state != nullptr)
    {
        std::cout << R"(<?xml version="1.0" encoding="UTF-8" ?>)"                       << std::endl
                  << "<facade>"                                                         << std::endl
                  << "    <apiVersion>v" << state->api_version << "</apiVersion>"       << std::endl
                  << "    <devices>"                                                    << std::endl;

        facade_device_info *info = state->devices;

        if (info != nullptr)
        {
            std::string indent = "        ";

            do
            {
                print_xml(info, indent);
                info = info->next;
            } while(info != state->devices);
        }

        std::cout << "    </devices>"                                                   << std::endl
                  << "</facade>"                                                        << std::endl;

        facade_dispose_state(&state);
    }

    return with(code);
}