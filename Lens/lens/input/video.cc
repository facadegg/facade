#ifdef LENS_FEATURE_FILE_IO
extern "C" {
#define __STDC_CONSTANT_MACROS

#include <libavutil/timestamp.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
}
#endif

#include "lens.h"
#include <string>

bool load_video(const std::string &path, lens::face_pipeline &pipeline)
{
    AVFormatContext *format_ctx = nullptr;

    if (avformat_open_input(&format_ctx, path.c_str(), NULL, NULL) < 0)
        throw std::runtime_error("Failed to open input file");

    // Retrieve stream information
    if (avformat_find_stream_info(format_ctx, NULL) < 0) {
        printf("Could not find stream information.\n");
        avformat_close_input(&format_ctx);
        return 1;
    }

    // Find the first video stream
    int videoStreamIndex = -1;
    for (int i = 0; i < format_ctx->nb_streams; i++) {
        if (format_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoStreamIndex = i;
            break;
        }
    }

    if (videoStreamIndex == -1) {
        printf("Could not find a video stream.\n");
        avformat_close_input(&format_ctx);
        return 1;
    }

    // Retrieve the video codec parameters
    AVCodecParameters *codecParams = format_ctx->streams[videoStreamIndex]->codecpar;

    // Find the video decoder
    const AVCodec *codec = avcodec_find_decoder(codecParams->codec_id);
    if (!codec) {
        printf("Could not find a suitable video decoder.\n");
        avformat_close_input(&format_ctx);
        return 1;
    }

    // Initialize the codec format_ctx
    AVCodecContext *codec_ctx = avcodec_alloc_context3(codec);
    if (avcodec_parameters_to_context(codec_ctx, codecParams) < 0) {
        printf("Failed to initialize the codec format_ctx.\n");
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&format_ctx);
        return 1;
    }

    // Open the codec
    if (avcodec_open2(codec_ctx, codec, NULL) < 0) {
        printf("Failed to open the video codec.\n");
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&format_ctx);
        return 1;
    }

    int frame_index = 0;

    // Read each frame
    AVPacket packet;
    while (av_read_frame(format_ctx, &packet) >= 0) {
        // Process only video packets
        if (packet.stream_index == videoStreamIndex) {
            // Send packet to the decoder
            if (avcodec_send_packet(codec_ctx, &packet) < 0) {
                printf("Failed to send a packet to the decoder.\n");
                av_packet_unref(&packet);
                continue;
            }

            AVFrame *frame = av_frame_alloc();

            // Receive decoded frame from the decoder
            int ret = avcodec_receive_frame(codec_ctx, frame);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                std::cerr << "Dropping frame" << std::endl;
                av_frame_free(&frame);
                av_packet_unref(&packet);
                continue;
            } else if (ret < 0) {
                printf("Error while receiving a frame from the decoder.\n");
                av_frame_free(&frame);
                av_packet_unref(&packet);
                break;
            }

            // Convert the frame to RGBA format
            AVFrame* rgbaFrame = av_frame_alloc();
            if (!rgbaFrame) {
                std::cerr << "Failed to allocate RGBA frame" << std::endl;
                avcodec_free_context(&codec_ctx);
                avformat_close_input(&format_ctx);
                return true;
            }

            std::cout << "FRAME INDEX" << frame_index << std::endl;

            int bufferSize = av_image_get_buffer_size(AV_PIX_FMT_RGBA,
                                                      codec_ctx->width,
                                                      codec_ctx->height,
                                                      1);
            auto* buffer = new uint8_t[bufferSize];

            av_image_fill_arrays(rgbaFrame->data, rgbaFrame->linesize,
                                 buffer, AV_PIX_FMT_RGBA,
                                 codec_ctx->width, codec_ctx->height, 1);

            struct SwsContext* swsContext = sws_getContext(codec_ctx->width,
                                                           codec_ctx->height,
                                                           codec_ctx->pix_fmt,
                                                           codec_ctx->width,
                                                           codec_ctx->height,
                                                           AV_PIX_FMT_BGRA,
                                                           SWS_BILINEAR,
                                                           nullptr,
                                                           nullptr,
                                                           nullptr);

            if (!swsContext) {
                std::cerr << "Failed to create SwsContext" << std::endl;
                av_free(buffer);
                av_frame_free(&rgbaFrame);
                avcodec_free_context(&codec_ctx);
                avformat_close_input(&format_ctx);
                return true;
            }

            sws_scale(swsContext, frame->data, frame->linesize,
                      0, codec_ctx->height,
                      rgbaFrame->data, rgbaFrame->linesize);

            cv::Mat image(static_cast<int>(codec_ctx->height), static_cast<int>(codec_ctx->width), CV_8UC4, buffer);
            pipeline << image;

            std::this_thread::sleep_for(frame_index < 8 ? std::chrono::milliseconds(500) : std::chrono::milliseconds(100));
            frame_index++;

            av_frame_free(&frame);
        }

        av_packet_unref(&packet);
    }

    // Close the codec
    avcodec_free_context(&codec_ctx);

    // Close the video file
    avformat_close_input(&format_ctx);

    return true;
}