//
// Created by Shukant Pal on 6/19/23.
//

#include <filesystem>
#include <memory>
#include <string>

#include "base_output.h"
#include "facade_output.h"
#include "file_output.h"

namespace fs = std::filesystem;

namespace
{

std::vector<std::string> video_formats = {"mp4", "mov", "avi", "mkv", "wmv"};

bool match(const std::vector<std::string> &formats, const std::string &path)
{
    for (auto it = formats.begin(); it != formats.end(); ++it)
        if (path.ends_with(*it))
            return true;

    return false;
}

}

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

    fs::path dst_path{dst};

    if (match(video_formats, dst_path))
        return std::unique_ptr<base_output>(new file_output(pipeline, dst));

    return nullptr;
}

} // namespace lens