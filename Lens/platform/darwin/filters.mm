//
// Created by Shukant Pal on 4/15/23.
//

#include "filters.hpp"

#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

namespace lens
{

class gaussian_blur_impl : public gaussian_blur
{
public:
    gaussian_blur_impl();
    ~gaussian_blur_impl() noexcept;
    double get_radius();
    void set_radius(double);
    virtual void run(cv::Mat& in, cv::Mat& out);
private:
    double radius;
};

gaussian_blur::~gaussian_blur() noexcept { }

std::unique_ptr<gaussian_blur> gaussian_blur::build()
{
    return std::unique_ptr<gaussian_blur>(new gaussian_blur_impl());
}

gaussian_blur_impl::gaussian_blur_impl() :
        radius(0)
{ }

gaussian_blur_impl::~gaussian_blur_impl() noexcept
{ }

double gaussian_blur_impl::get_radius()
{
    return radius;
}

void gaussian_blur_impl::set_radius(double value)
{
    this->radius = value;
}

void gaussian_blur_impl::run(cv::Mat &in, cv::Mat &out)
{
    // Create a Metal device and command queue
    id <MTLDevice> device = MTLCreateSystemDefaultDevice();
    id <MTLCommandQueue> commandQueue = [device newCommandQueue];

    const int width = in.cols;
    const int height = in.rows;
    const int channels = in.channels();

    assert(channels == 1);

    // Create a MPS image descriptor for the input image
    auto *texture_descriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                         width:width
                                        height:height
                                     mipmapped:false];

    // Create a MPS image from the input image data
    NSData *inputData = [[NSData alloc] initWithBytes:in.data length:in.total() * in.elemSize()];
    id <MTLTexture> inputTexture = [device newTextureWithDescriptor:texture_descriptor];
    [inputTexture
            replaceRegion:MTLRegionMake2D(0, 0, in.cols, in.rows)
            mipmapLevel:0
            withBytes:inputData.bytes
            bytesPerRow:in.step[0]];

    // Create a MPS image for the output image data
    texture_descriptor.usage = MTLTextureUsageShaderWrite;
    id <MTLTexture> outputTexture = [device newTextureWithDescriptor:texture_descriptor];

    // Create a MPS Gaussian blur filter
    MPSImageGaussianBlur *gaussianBlurFilter = [[MPSImageGaussianBlur alloc] initWithDevice:device sigma:radius];

    @autoreleasepool
    {
        // Create a Metal command buffer and encoder
        id <MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

        // Encode the Gaussian blur filter
        [gaussianBlurFilter encodeToCommandBuffer:commandBuffer sourceTexture:inputTexture destinationTexture:outputTexture];

        // End the encoding and execute the command buffer
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
    }

    // Create an OpenCV Mat for the output image
    [outputTexture getBytes:out.data
                bytesPerRow:out.step[0]
                 fromRegion:MTLRegionMake2D(0, 0, texture_descriptor.width, texture_descriptor.height)
                mipmapLevel:0];

    [inputData release];
    [gaussianBlurFilter release];
    [inputTexture release];
    [outputTexture release];
    [texture_descriptor release];
    [commandQueue release];
    [device release];
}

} // namespace lens
