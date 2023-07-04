//
// Created by Shukant Pal on 6/1/23.
//

#include <oneapi/tbb.h>

#include "base_output.h"

namespace fs = std::filesystem;

namespace lens
{

base_output::base_output(face_pipeline &pipeline) :
    pipeline(pipeline),
    pipe_thread(&base_output::pipe, this)
{ }

base_output::~base_output() noexcept
{
    pipe_thread.detach();
}

bool base_output::handle(cv::Mat &image) { return false; }

[[noreturn]] void base_output::pipe()
{
    cv::Mat image;

    while (true)
    {
        pipeline >> image;

        if (!handle(image))
            buffer_queue.push(image);
    }
}

} // namespace lens