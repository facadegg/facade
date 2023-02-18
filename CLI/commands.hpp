#ifndef FACADE_CLI_COMMANDS_HPP
#define FACADE_CLI_COMMANDS_HPP

#include <boost/program_options.hpp>

int command_device_create(boost::program_options::variables_map& vm);
int command_device_edit  (boost::program_options::variables_map& vm);
int command_device_delete(boost::program_options::variables_map& vm);
int command_state_import (boost::program_options::variables_map& vm);
int command_state_export (boost::program_options::variables_map& vm);

#endif /* FACADE_CLI_COMMANDS_HPP */