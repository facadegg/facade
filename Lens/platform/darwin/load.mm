
#include "lens.hpp"

#include <string>

#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

namespace
{

static std::vector<std::string> image_formats = {"jpg", "jpeg", "png", "gif", "bmp"};
static std::vector<std::string> video_formats = {"mp4", "mov", "avi", "mkv", "wmv"};

bool match(const std::vector<std::string>& formats, const std::string& path)
{
    for (auto it = formats.begin(); it != formats.end(); ++it)
        if (path.ends_with(*it))
            return true;

    return false;
}

bool load_image(NSString *path, lens::face_pipeline& pipeline)
{
    NSURL *url = [NSURL fileURLWithPath:path];
    CIImage *image = [CIImage imageWithContentsOfURL:url];
    CIContext *context = [CIContext context];

    CVPixelBufferRef pixel_buffer;
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          image.extent.size.width,
                                          image.extent.size.height,
                                          kCVPixelFormatType_32BGRA,
                                          nil,
                                          &pixel_buffer);

    if (result != kCVReturnSuccess) {
        std::cout << "There was an error opening the buffer " <<  result << std::endl;
    }

    [context render:image toCVPixelBuffer:pixel_buffer];

    CVPixelBufferLockBaseAddress(pixel_buffer, kCVPixelBufferLock_ReadOnly);

    void *base_address = CVPixelBufferGetBaseAddress(pixel_buffer);
    size_t bytes_per_row = CVPixelBufferGetBytesPerRow(pixel_buffer);
    size_t width = CVPixelBufferGetWidth(pixel_buffer);
    size_t height = CVPixelBufferGetHeight(pixel_buffer);

    std::cout << "Loaded image of dimensions " << width << "x" << image.extent.size.height << " bytes per row " << bytes_per_row << std::endl;

    size_t pixels_count = width * height;
    auto *image_buffer = new uint8_t[pixels_count * 3];
    for (int i = 0, j = 0; i < pixels_count * 4; i++)
    {
        if (i % 4 < 3)
        {
            image_buffer[j] = reinterpret_cast<const uint8_t *>(base_address)[i];
            ++j;
        }
    }
    const uint8_t *src = reinterpret_cast<const uint8_t *>(base_address);
    uint8_t *dst = image_buffer;
    for (size_t row = 0; row < height; ++row)
    {
        for (size_t col = 0; col < width; ++col)
        {
            *(dst++) = src[col * 4];
            *(dst++) = src[col * 4 + 1];
            *(dst++) = src[col * 4 + 2];
        }

        src += bytes_per_row;
    }
    CVPixelBufferUnlockBaseAddress(pixel_buffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferRelease(pixel_buffer);

    lens::frame frame = {
            .id = 0,
            .pixels = image_buffer,
            .channels = 3,
            .width = width,
            .height = height,
    };

    pipeline << frame;

    [image release];
    [url release];

    return true;
}

} // namespace

namespace lens
{

bool load(const std::string& cxx_path, int frame_rate, face_pipeline& pipeline)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithCString:cxx_path.c_str()];

    if ([fileManager fileExistsAtPath:path])
    {
        if (match(image_formats, cxx_path))
            return load_image(path, pipeline);

        std::cout << "Unknown file type" << std::endl;
    }
    else
    {
        std::cout << "No file found at that path" << std::endl;
    }

    return false;
}

} // namespace lens