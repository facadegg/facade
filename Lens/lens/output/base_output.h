//
// Created by Shukant Pal on 6/19/23.
//

#pragma once

#include <oneapi/tbb.h>
#include <opencv2/opencv.hpp>

#include "facade.h"
#include "lens.h"

namespace lens
{

class base_output
{
  public:
    virtual ~base_output() noexcept;

  protected:
    explicit base_output(face_pipeline &pipeline);

    face_pipeline &pipeline;
    oneapi::tbb::concurrent_bounded_queue<cv::Mat> buffer_queue;

  protected:
    virtual bool handle(cv::Mat &image);

  private:
    std::thread pipe_thread;

    [[noreturn]] void pipe();
    void push(cv::Mat &image);
};

} // namespace lens
