//
// Created by Shukant Pal on 6/19/23.
//

#pragma once

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
}

#include <atomic>

#include "base_output.h"
#include "lens.h"

namespace lens
{

class file_output : public base_output
{
public:
    explicit file_output(face_pipeline &pipeline, const std::string &output_path);
    ~file_output() noexcept override;

protected:
    bool handle(cv::Mat &image) override;
private:
    std::string filepath;
    AVFormatContext *context;
    const AVCodec *codec;
    AVCodecContext *codec_ctx;
    AVFrame *frame;
    AVStream *stream;
    struct SwsContext *sws_ctx;
    bool did_init;
    int pts;

    bool init(size_t width, size_t height);
    void flush_packets();
};

} // namespace lens