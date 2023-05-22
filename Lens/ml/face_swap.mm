//
// Created by Shukant Pal on 4/15/23.
//

#include "ml.h"
#include "model_loader.h"

#import <CoreML/CoreML.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <simd/simd.h>

namespace
{

typedef struct {
    vector_float2 dst_position;
    vector_float2 src_position;
} Vertex;

} // namespace

namespace lens
{

const float NINE_ZEROS[9] = { 0, 0, 0,
                              0, 0, 0,
                              0, 0, 0};

class face_swap_impl : public face_swap_model
{
public:
    explicit face_swap_impl(MLModel const *,
                            id<MTLDevice> device,
                            id<MTLLibrary> compositor);
    ~face_swap_impl() noexcept override;
    void run(cv::Mat& in_face, cv::Mat& out_celebrity_face, cv::Mat& out_celebrity_face_mask) override;
    void composite(cv::Mat& dst, const face& extraction, cv::Mat& face, cv::Mat& out_celebrity_face, cv::Mat& out_celebrity_face_mask) override;
private:
    MLModel const* model;
    id<MTLDevice> device;
    id<MTLLibrary> compositor;
    MTLRenderPipelineDescriptor* compositor_pipeline_descriptor;
    id<MTLRenderPipelineState> compositor_state;
};

face_swap_impl::face_swap_impl(MLModel const *model, id<MTLDevice> device, id<MTLLibrary> compositor) :
        model(model),
        device(device),
        compositor(compositor),
        compositor_pipeline_descriptor([[MTLRenderPipelineDescriptor alloc] init])
{
    [compositor_pipeline_descriptor setVertexFunction:[compositor newFunctionWithName:@"vertex_main"]];
    [compositor_pipeline_descriptor setFragmentFunction:[compositor newFunctionWithName:@"fragment_main"]];
    [[compositor_pipeline_descriptor colorAttachments][0] setPixelFormat:MTLPixelFormatRGBA8Unorm];

    compositor_state = [device newRenderPipelineStateWithDescriptor:compositor_pipeline_descriptor error:nil];
}

face_swap_model::~face_swap_model() = default;

face_swap_impl::~face_swap_impl() noexcept
{
    [this->model release];
    this->model = nullptr;

    [[compositor_pipeline_descriptor vertexFunction] release];
    [[compositor_pipeline_descriptor fragmentFunction] release];
    [compositor_pipeline_descriptor release];
    compositor_pipeline_descriptor = nullptr;
    [compositor_state release];
    compositor_state = nullptr;
    [compositor release];
    compositor = nullptr;
    [device release];
    device = nullptr;
}

void face_swap_impl::run(cv::Mat &in_face, cv::Mat &out_celebrity_face, cv::Mat &out_celebrity_face_mask)
{
    NSError *error = nil;
    MLMultiArray *in_face_data = [[MLMultiArray alloc] initWithDataPointer: reinterpret_cast<void *>(in_face.data)
                                                                     shape:@[@1, @224, @224, @3]
                                                                  dataType:MLMultiArrayDataTypeFloat
                                                                   strides:@[@672, @672, @3, @1]
                                                               deallocator:nil
                                                                     error: &error];

    if (error)
    {
        NSLog(@"Failed to prepare image input: %@", error);
        @throw error;
    }

    auto options = @{
            @"in_face:0": [MLFeatureValue featureValueWithMultiArray:in_face_data]
    };
    MLDictionaryFeatureProvider* input_provider = [[MLDictionaryFeatureProvider alloc]
            initWithDictionary:options
                         error:&error];
    id<MLFeatureProvider> input = input_provider;

    @autoreleasepool
    {
        id <MLFeatureProvider> output = [this->model predictionFromFeatures:input error:&error];

        if (error) {
            NSLog(@"Failed to execute face-swap model: %@", error);
            @throw error;
        }

        MLMultiArray *out_celebrity_face_data = [[output featureValueForName:@"out_celeb_face:0"] multiArrayValue];
        MLMultiArray *out_celebrity_face_mask_data = [[output featureValueForName:@"out_celeb_face_mask:0"] multiArrayValue];

        out_celebrity_face = cv::Mat(224, 224, CV_32FC3, [out_celebrity_face_data dataPointer]).clone();
        out_celebrity_face_mask = cv::Mat(224, 224, CV_32FC1, [out_celebrity_face_mask_data dataPointer]).clone();
    }

    [input_provider release];
    [in_face_data release];
}

void face_swap_impl::composite(cv::Mat& dst,
                               const face& extraction,
                               cv::Mat& face,
                               cv::Mat& out_celeb_face,
                               cv::Mat& out_celeb_face_mask)
{
    assert(dst.channels() == 4);
    assert(face.channels() == 3);
    assert(out_celeb_face.channels() == 3);
    assert(out_celeb_face_mask.channels() == 1);

    const int width = face.cols;
    const int height = face.rows;

    assert(width == 224 && out_celeb_face.cols == 224);
    assert(height == 224 && out_celeb_face.rows == 224);

    // Preprocessing
    out_celeb_face = color_transfer(out_celeb_face, face);
    cv::cvtColor(out_celeb_face, out_celeb_face, cv::COLOR_BGR2BGRA);

    id<MTLCommandQueue> command_queue = [device newCommandQueue];

    auto* mask_descriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                         width:width
                                        height:height
                                     mipmapped:false];
    auto* plane_descriptor = [MTLTextureDescriptor
                             texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                          width:width*3
                                                         height:height*3
                                                      mipmapped:false];
    auto* face_descriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                         width:out_celeb_face.cols
                                        height:out_celeb_face.rows
                                     mipmapped:false];
    auto* frame_descriptor = [MTLTextureDescriptor
                              texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:dst.cols
                                                          height:dst.rows
                                                       mipmapped:false];
    mask_descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    face_descriptor.usage = MTLTextureUsageShaderRead;
    frame_descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    plane_descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    id<MTLTexture> mask_texture = [device newTextureWithDescriptor:mask_descriptor];
    id<MTLTexture> plane0_texture = [device newTextureWithDescriptor:plane_descriptor];
    id<MTLTexture> plane1_texture = [device newTextureWithDescriptor:plane_descriptor];

    id<MTLTexture> face_texture = [device newTextureWithDescriptor:face_descriptor];

    id<MTLTexture> in_texture = [device newTextureWithDescriptor:frame_descriptor];
    id<MTLTexture> out_texture = [device newTextureWithDescriptor:frame_descriptor];

    [mask_texture
        replaceRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0
            withBytes:out_celeb_face_mask.data
          bytesPerRow:out_celeb_face_mask.step[0]];
    [face_texture
        replaceRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0
            withBytes:out_celeb_face.data
          bytesPerRow:out_celeb_face.step[0]];
    [in_texture
        replaceRegion:MTLRegionMake2D(0, 0, dst.cols, dst.rows)
          mipmapLevel:0
            withBytes:dst.data
          bytesPerRow:dst.step[0]];
    [out_texture
            replaceRegion:MTLRegionMake2D(0, 0, dst.cols, dst.rows)
              mipmapLevel:0
                withBytes:dst.data
              bytesPerRow:dst.step[0]];

    const int radius = 6;
    MPSImageErode* erode = [[MPSImageErode alloc] initWithDevice:device
                                                     kernelWidth:static_cast<NSUInteger>(3)
                                                    kernelHeight:static_cast<NSUInteger>(3)
                                                          values:NINE_ZEROS];
    MPSImageGaussianBlur* blur = [[MPSImageGaussianBlur alloc] initWithDevice:device sigma:radius];

    @autoreleasepool
    {
        id<MTLCommandBuffer> command_buffer = [command_queue commandBuffer];

        auto mask_region = MTLRegionMake2D(0, 0, width, height);
        auto clip_region = MTLRegionMake2D(width + radius, height + radius, width - radius * 2, height - radius * 2);

        MTLRenderPassDescriptor* plane0_clear_descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        plane0_clear_descriptor.colorAttachments[0].texture = plane0_texture;
        plane0_clear_descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        plane0_clear_descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        id<MTLRenderCommandEncoder> plane0_clear = [command_buffer renderCommandEncoderWithDescriptor:plane0_clear_descriptor];
        [plane0_clear endEncoding];

        auto* blit = [command_buffer blitCommandEncoder];
        [blit copyFromTexture: mask_texture
                  sourceSlice: 0
                  sourceLevel: 0
                 sourceOrigin: mask_region.origin
                   sourceSize: mask_region.size
                    toTexture: plane0_texture
             destinationSlice: 0
             destinationLevel: 0
            destinationOrigin: MTLOriginMake(width, height, 0)];
        [blit endEncoding];

        [erode encodeToCommandBuffer:command_buffer sourceTexture:plane0_texture destinationTexture:plane1_texture];
        [erode encodeToCommandBuffer:command_buffer sourceTexture:plane1_texture destinationTexture:plane0_texture];

        MTLRenderPassDescriptor* plane1_clear_descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        plane1_clear_descriptor.colorAttachments[0].texture = plane1_texture;
        plane1_clear_descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        plane1_clear_descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        id<MTLRenderCommandEncoder> plane1_clear = [command_buffer renderCommandEncoderWithDescriptor:plane1_clear_descriptor];
        [plane1_clear endEncoding];

        auto* clip = [command_buffer blitCommandEncoder];
        [clip copyFromTexture: plane0_texture
                  sourceSlice: 0
                  sourceLevel: 0
                 sourceOrigin: clip_region.origin
                   sourceSize: clip_region.size
                    toTexture: plane1_texture
             destinationSlice: 0
             destinationLevel: 0
            destinationOrigin: clip_region.origin];
        [clip endEncoding];

        [blur encodeToCommandBuffer:command_buffer sourceTexture:plane1_texture destinationTexture:plane0_texture];

        MTLRenderPassDescriptor *render_pass_descriptor = [[MTLRenderPassDescriptor alloc] init];
        render_pass_descriptor.colorAttachments[0].texture = out_texture;
        render_pass_descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
        render_pass_descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        render_pass_descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        const cv::Mat backwards_transform = extraction.transform.inv()(cv::Rect(0, 0, 3, 2));
        double a = backwards_transform.at<double>(0, 0);
        double b = backwards_transform.at<double>(0, 1);
        double tx = backwards_transform.at<double>(0, 2);
        double c = backwards_transform.at<double>(1, 0);
        double d = backwards_transform.at<double>(1, 1);
        double ty = backwards_transform.at<double>(1, 2);
        Vertex tl = {.dst_position = simd_make_float2(tx / dst.cols,  ty / dst.rows), .src_position = simd_make_float2(0, 0)};
        Vertex tr = {.dst_position = simd_make_float2((a*width + tx) / dst.cols, (c*width + ty) / dst.rows), .src_position = simd_make_float2(1, 0)};
        Vertex br = {.dst_position = simd_make_float2((a*width + b*height + tx) / dst.cols, (c*width + d*height + ty) / dst.rows), .src_position = simd_make_float2(1, 1)};
        Vertex bl = {.dst_position = simd_make_float2((b*height + tx) / dst.cols, (d*height + ty) / dst.rows), .src_position = simd_make_float2(0, 1)};

        Vertex vertices[6] = {
                tl, tr, br,
                br, bl, tl
        };
        id<MTLRenderCommandEncoder> render_encoder = [command_buffer renderCommandEncoderWithDescriptor:render_pass_descriptor];
        id<MTLBuffer> vertex_buffer = [device newBufferWithBytes:vertices
                                                          length:sizeof(vertices)
                                                         options:MTLResourceCPUCacheModeDefaultCache];
        MTLViewport viewport = { .originX = 0, .originY = 0, .width = static_cast<double>(dst.cols), .height = static_cast<double>(dst.rows) };
        [render_encoder setRenderPipelineState:compositor_state];
        [render_encoder setViewport:viewport];
        [render_encoder setCullMode:MTLCullModeNone];
        [render_encoder setVertexBuffer:vertex_buffer offset:0 atIndex:0];
        [render_encoder setFragmentTexture:in_texture atIndex:0];
        [render_encoder setFragmentTexture:face_texture atIndex:1];
        [render_encoder setFragmentTexture:mask_texture atIndex:2];
        [render_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [render_encoder endEncoding];

        [command_buffer commit];
        [command_buffer waitUntilCompleted];

        [render_pass_descriptor release];
        [vertex_buffer release];
    }

    memset(dst.data, 0, dst.total()*dst.elemSize());

    [out_texture getBytes:dst.data
              bytesPerRow:dst.step[0]
               fromRegion:MTLRegionMake2D(0, 0, dst.cols, dst.rows)
              mipmapLevel:0];

    [erode release];
    [blur release];
    [out_texture release];
    [in_texture release];
    [plane1_texture release];
    [plane0_texture release];
    [mask_texture release];
    [frame_descriptor release];
    [face_descriptor release];
    [plane_descriptor release];
    [mask_descriptor release];
    [command_queue release];
}

std::unique_ptr<face_swap_model> face_swap_model::build(const std::filesystem::path& path)
{
    MLModel *model = load_model(path);

    if (!model)
        return nullptr;

    NSError *error = nil;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    std::string compositor_path = (path.parent_path() / std::filesystem::path("face_compositor.metallib")).string();
    NSString* const compositor_pathstr = [NSString stringWithCString:compositor_path.c_str() encoding:NSASCIIStringEncoding];
    NSURL* const compositor_url = [NSURL fileURLWithPath:compositor_pathstr];
    id<MTLLibrary> compositor = [device newLibraryWithURL:compositor_url error:&error];

    if (error) {
        NSLog(@"Failed to load Metal library: %@", error);
        return nil;
    }

    return std::unique_ptr<face_swap_model>(new face_swap_impl(model, device, compositor));
}

} // namespace lens
