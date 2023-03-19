//
// Created by Shukant Pal on 3/18/23.
//

#include "mirage.hpp"
#include <iostream>

facade::pipeline_control_delegate::pipeline_control_delegate(oneapi::tbb::concurrent_queue<facade::frame>& queue) :
    queue(queue),
    ptr(nullptr),
    ptr_ptr(&ptr)
{
}

std::tuple<facade::video_pipeline *, facade::frame> facade::pipeline_control_delegate::operator()(oneapi::tbb::flow_control &fc)
{
    facade::frame next = {};

    if (!queue.try_pop(next))
        fc.stop();

    std::cout << "PTR IS " << *ptr_ptr << std::endl;

    return { *ptr_ptr, next };
}

void facade::pipeline_control_delegate::operator<<(facade::video_pipeline *pipeline)
{
    std::cout << "HERE " << pipeline << std::endl;
    this->ptr = pipeline;
}

