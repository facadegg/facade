//
// Created by Shukant Pal on 2/18/23.
//

#include <boost/program_options.hpp>
#include <iostream>

#include "commands.hpp"
#include "facade.h"

namespace po = boost::program_options;

int main(int argc, char **argv)
{
    po::options_description options("Options");
    options.add_options()
            ("scope", "device | state | help")
            ("command", "create | edit | delete | find for 'device' scope.\nimport | export for 'state' scope.")
            ("name",        po::value<std::string>(),   "The name of the object")
            ("uid",         po::value<std::string>(),   "The unique identifier of the object")
            ("type",        po::value<std::string>(),   "The type of device. Must be 'video' ")
            ("width",       po::value<int>(),           "The width of the video")
            ("height",      po::value<int>(),           "The height of the video")
            ("frame-rate",  po::value<int>(),           "The frame rate of the video")
            ("output,o",    po::value<std::string>(),   "The output format, must be 'xml'");

    po::positional_options_description positional;
    positional.add("scope", 1);
    positional.add("command", 1);

    po::variables_map vm;

    try
    {
        po::parsed_options parsed = po::command_line_parser(argc, argv)
                .options(options)
                .positional(positional)
                .allow_unregistered()
                .run();
        po::store(parsed, vm);
        po::notify(vm);
    }
    catch (po::error& e)
    {
        std::cerr << "Invalid command: " << e.what() << ". Use 'facade help' for options." << std::endl;
        return -1;
    }

    std::string scope = vm.count("scope") ? vm["scope"].as<std::string>() : "help";

    if (scope == "help")
    {
        std::cout << "Usage:" << std::endl
                  << "\tfacade [scope] [command] [options]" << std::endl;
        std::cout << options << std::endl;
    }
    else if(scope == "device" || scope == "state")
    {
        if (vm.count("command"))
        {
            facade_error_code init_error = facade_init();

            if (init_error == facade_error_not_installed)
            {
                std::cerr << "Facade is not installed! Go to https://facade.gg" << std::endl;
                return -1;
            }

            std::string command = vm["command"].as<std::string>();

            if (scope == "device")
            {
                if      (command == "create") command_device_create(vm);
                else if (command == "edit")   command_device_edit(vm);
                else if (command == "delete") command_device_delete(vm);
                else if (command == "find")   command_device_find(vm);
                else
                {
                    std::cout << "Invalid command " << command
                              << " for 'device' scope. Use 'facade help' for options" << std::endl;
                    return -1;
                }
            }
            else
            {
                if      (command == "import") command_state_import(vm);
                else if (command == "export") command_state_export(vm);
                else
                {
                    std::cout << "Invalid command " << command
                              << " for 'state' scope. Use 'facade help' for options" << std::endl;
                    return -1;
                }
            }
        }
        else
        {
            std::cout << "No command passed to facade " << scope << ". Use 'facade help' for options" << std::endl;
            return -1;
        }
    }
    else
    {
        std::cout << "Unknown scope '" << scope << "'. Use 'facade help' for options." << std::endl;
        return -1;
    }
}