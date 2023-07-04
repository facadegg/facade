//
// Created by Shukant Pal on 6/19/23.
//

#define __STDC_CONSTANT_MACROS

extern "C" {
#include <libavutil/timestamp.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

#include "file_output.h"

namespace
{

void av_print_error(const std::string &message, int av_code)
{
    constexpr int error_length = 100;
    char error_description[error_length] = { 0 };
    bool error_found = av_strerror(av_code, error_description, error_length) == 0;

    std::cout << message << " (" << av_code << ", " << (error_found ? error_description : "unknown error") << ")" << std::endl;
}

} // namespace

namespace lens
{

file_output::file_output(lens::face_pipeline &pipeline, const std::string &output_path) :
        base_output(pipeline),
        filepath(output_path),
        context(nullptr),
        codec(avcodec_find_encoder(AV_CODEC_ID_H264)),
        codec_ctx(avcodec_alloc_context3(codec)),
        frame(av_frame_alloc()),
        stream(nullptr),
        sws_ctx(nullptr),
        did_init(false),
        pts(0)
{
    int context_code = avformat_alloc_output_context2(&context, nullptr, nullptr, output_path.c_str());
    if (!context || context_code < 0)
        throw std::runtime_error("Failed to create output context to write video");

    if (!frame)
        throw std::runtime_error("Failed to initialize frame");

    stream = avformat_new_stream(context, nullptr);
}

file_output::~file_output() noexcept
{
    avcodec_send_frame(codec_ctx, nullptr);
    flush_packets();

    av_frame_free(&frame);
    av_write_trailer(context);
    avio_closep(&context->pb);
    avformat_free_context(context);
}

bool file_output::handle(cv::Mat &image)
{
    if (!did_init)
    {
        init(image.cols, image.rows);
    }

    auto *data = reinterpret_cast<uint8_t *>(image.data);
    int stride[1] = { image.cols * 4 };
    sws_scale(sws_ctx, &data, stride, 0, codec_ctx->height, frame->data, frame->linesize);

    int p = pts++;
    frame->pts = p * 512;

    AVPacket packet{nullptr};
    int code;

    code = avcodec_send_frame(codec_ctx, frame);
    if (code < 0) {
        av_print_error("Failed to send frame for encoding", code);
        return true;
    }

    flush_packets();

    delete[] data;

    return true;
}

bool file_output::init(size_t width, size_t height)
{
    codec_ctx->codec_id = AV_CODEC_ID_H264;
    codec_ctx->codec_type = AVMEDIA_TYPE_VIDEO;
    codec_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    codec_ctx->width = width;
    codec_ctx->height = height;
    codec_ctx->framerate = {30,1};
    codec_ctx->time_base = {1,15360};
    if (avcodec_open2(codec_ctx, codec, nullptr) < 0) {
        std::cerr << "Failed to open video codec" << std::endl;
    }

    frame->width = width;
    frame->height = height;
    frame->format = AV_PIX_FMT_YUV420P;
    frame->key_frame = 1;
    frame->pict_type = AV_PICTURE_TYPE_I;
    frame->duration = 1;
    int bufferSize = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, width, height, 1);
    uint8_t* buffer = (uint8_t*)av_malloc(bufferSize);
    av_image_fill_arrays(frame->data, frame->linesize, buffer, AV_PIX_FMT_YUV420P, width, height, 1);

    stream->codecpar->codec_type = AVMEDIA_TYPE_VIDEO;
    stream->codecpar->codec_id = AV_CODEC_ID_H264;
    stream->codecpar->codec_tag = 0;
    stream->codecpar->width = width;
    stream->codecpar->height = height;
    stream->time_base = { 1, 12800 };

    sws_ctx = sws_getContext(codec_ctx->width,
                             codec_ctx->height,
                             AV_PIX_FMT_BGRA,
                             codec_ctx->width,
                             codec_ctx->height,
                             codec_ctx->pix_fmt,
                             SWS_BILINEAR,
                             nullptr,
                             nullptr,
                             nullptr);

    int ret = avio_open(&context->pb, filepath.c_str(), AVIO_FLAG_WRITE);
    if (ret < 0) {
        throw std::runtime_error("Failed to open output file");
    }

    int open_code = avformat_write_header(context, nullptr);
    if (open_code < -1) {
        constexpr int error_length = 100;
        char error_description[error_length] = { 0 };
        bool error_found = av_strerror(open_code, error_description, error_length) == 0;

        std::cout << "ERROR" <<  (error_found ? error_description :  "Failed to write header (unknown error)" )<< std::endl;
        throw std::runtime_error(error_found ? error_description :  "Failed to write header (unknown error)");
    }

    did_init = true;
}

void file_output::flush_packets()
{
    AVPacket packet{nullptr};

    while (avcodec_receive_packet(codec_ctx, &packet) >= 0) {
        if (av_write_frame(context, &packet) < 0) {
            std::cerr << "Failed to write packet" << std::endl;
            av_packet_unref(&packet);
            break;
        }

        av_packet_unref(&packet);
    }
}

} // namespace lens