//
// Created by Shukant Pal on 6/19/23.
//

#include <memory>
#include <string>

#include "base_output.h"
#include "facade_output.h"

namespace lens
{

std::unique_ptr<base_output> output(face_pipeline &pipeline, std::string &dst, bool loop)
{
    facade_device *device = nullptr;

    facade_init();
    facade_find_device_by_name(dst.c_str(), &device);
    if (!device)
        facade_find_device_by_uid(dst.c_str(), &device);

    if (!device && (loop || dst.find('.') == std::string::npos))
        throw std::runtime_error("The Facade device " + dst + " does not exist.");

    if (device)
        return std::unique_ptr<base_output>(new facade_output(pipeline, device));

    return nullptr;
}

} // namespace lens