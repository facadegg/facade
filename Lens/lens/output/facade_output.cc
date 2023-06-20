//
// Created by Shukant Pal on 6/19/23.
//

#include "facade_output.h"
#include <memory>

namespace lens
{

facade_output::facade_output(face_pipeline &pipeline, facade_device *device) :
    base_output(pipeline),
    device(device),
    flush_pending(true)
{
    facade_error_code open_code = facade_write_open(device);
    if (open_code != facade_error_none)
        throw std::runtime_error("Failed to open Facade device for writing video");

    facade_write_callback(
        device, reinterpret_cast<facade_callback>(facade_output::flush_stub), this);
}

facade_output::~facade_output() noexcept = default;

bool facade_output::handle(cv::Mat &frame_image)
{
    flush_mutex.lock();

    const bool was_pending = flush_pending;

    if (was_pending)
    {
        cv::Mat composited_image;

        if (device->width == frame_image.cols && device->height)
        {
            composited_image = frame_image;
        }
        else
        {
            composited_image = cv::Mat::zeros(cv::Size(device->width, device->height), CV_8UC4);
            cv::Rect placement;

            float scale = std::min(1.f,
                                   std::min(static_cast<float>(composited_image.rows) /
                                                static_cast<float>(frame_image.rows),
                                            static_cast<float>(composited_image.cols) /
                                                static_cast<float>(frame_image.cols)));

            placement.width = frame_image.cols * scale;
            placement.height = frame_image.rows * scale;
            placement.x = (composited_image.cols - placement.width) * 0.5f;
            placement.y = (composited_image.rows - placement.height) * 0.5f;

            std::cout << "TO " << placement << "with scale " << scale << std::endl;

            cv::resize(frame_image, frame_image, placement.size());
            frame_image.copyTo(composited_image(placement));
        }

        facade_write_frame(device,
                           (void *)composited_image.data,
                           4 * composited_image.cols * composited_image.rows);
        delete[] const_cast<uint8_t *>(frame_image.data);

        flush_pending = false;
    }

    flush_mutex.unlock();

    return was_pending;
}

void facade_output::flush_stub(facade_output *output)
{
    output->flush_mutex.lock();
    output->flush_pending = true;
    output->flush_mutex.unlock();

    // Handle the next frame if queued
    cv::Mat image;
    if (output->buffer_queue.try_pop(image))
        output->handle(image);
}

} // namespace lens