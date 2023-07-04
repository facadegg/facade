//
// Created by Shukant Pal on 6/19/23.
//

#pragma once

#include <mutex>

#include "base_output.h"
#include "facade.h"
#include "lens.h"

namespace lens
{

class facade_output : public base_output
{
  public:
    explicit facade_output(face_pipeline &pipeline, facade_device *);
    ~facade_output() noexcept override;

  protected:
    bool handle(cv::Mat &image) override;

  private:
    facade_device *device;
    std::mutex flush_mutex;
    bool flush_pending;

    static void flush_stub(facade_output *);
};

} // namespace lens