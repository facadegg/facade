//
// Created by Shukant Pal on 4/15/23.
//

#include "internal.h"
#include "model_loader.h"

#include <opencv2/opencv.hpp>

#import <CoreML/CoreML.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <simd/simd.h>

namespace fs = std::filesystem;

struct compositor_face2face
{
    cv::Mat dst;
    lens::face extraction;
    lens::face2face *value;
    oneapi::tbb::concurrent_queue<lens::face2face *> *face2face_pool;
    std::function<void(cv::Mat &)> callback;
};

@interface CompositorThread : NSThread

@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLLibrary> compositor;
@property(nonatomic, strong) MTLRenderPipelineDescriptor *compositor_pipeline_descriptor;
@property(nonatomic, strong) id<MTLRenderPipelineState> compositor_state;
@property(nonatomic) oneapi::tbb::concurrent_bounded_queue<compositor_face2face> *queue;

- (instancetype)initWithCompositor:(id<MTLLibrary>)compositor
                            device:(id<MTLDevice>)device
                             queue:(oneapi::tbb::concurrent_bounded_queue<compositor_face2face> *)
                                       queue;
- (void)composite:(compositor_face2face *)message;

@end

namespace
{

typedef struct
{
    vector_float2 dst_position;
    vector_float2 src_position;
} Vertex;

} // namespace

const float NINE_ZEROS[9] = {0, 0, 0, 0, 0, 0, 0, 0, 0};

namespace lens
{

class face_swap_impl : public face_swap
{
  public:
    explicit face_swap_impl(const std::vector<MLModel const *> &,
                            id<MTLDevice> device,
                            id<MTLLibrary> compositor);
    ~face_swap_impl() noexcept override;
    face2face *run(cv::Mat &) override;
    void composite(cv::Mat &dst,
                   const face &extraction,
                   face2face **,
                   std::function<void(cv::Mat &)>) override;

  private:
    std::atomic<size_t> model_choice;
    std::vector<MLModel const *> model_pool;
    oneapi::tbb::concurrent_bounded_queue<compositor_face2face> compositor_queue;
    CompositorThread *compositor_thread;
};

face_swap_impl::face_swap_impl(const std::vector<MLModel const *> &model_pool,
                               id<MTLDevice> device,
                               id<MTLLibrary> compositor) :
    model_choice(0),
    model_pool(model_pool),
    compositor_queue(),
    compositor_thread([[CompositorThread alloc] initWithCompositor:compositor
                                                            device:device
                                                             queue:&compositor_queue])
{
    compositor_queue.set_capacity(2);
    [compositor_thread start];
}

face_swap::~face_swap() = default;

face_swap_impl::~face_swap_impl() noexcept
{
    for (auto model = model_pool.begin(); model != model_pool.end(); model++)
        [*model release];

    [this->compositor_thread cancel];
    [this->compositor_thread dealloc];
    this->compositor_thread = nullptr;
}

face2face *face_swap_impl::run(cv::Mat &in_face)
{
    size_t choice = model_choice++ % model_pool.size();
    MLModel const *model = model_pool[choice];

    face2face *result = nullptr;
    if (!face2face_pool.try_pop(result))
        result = new face2face();

    NSError *error = nil;
    MLMultiArray *in_face_data =
        [[MLMultiArray alloc] initWithDataPointer:reinterpret_cast<void *>(in_face.data)
                                            shape:@[ @1, @224, @224, @3 ]
                                         dataType:MLMultiArrayDataTypeFloat
                                          strides:@[ @672, @672, @3, @1 ]
                                      deallocator:nil
                                            error:&error];

    if (error)
    {
        NSLog(@"Failed to prepare image input: %@", error);
        @throw error;
    }

    auto options = @{@"in_face:0" : [MLFeatureValue featureValueWithMultiArray:in_face_data]};
    MLDictionaryFeatureProvider *input_provider =
        [[MLDictionaryFeatureProvider alloc] initWithDictionary:options error:&error];
    id<MLFeatureProvider> input = input_provider;

    @autoreleasepool
    {
        id<MLFeatureProvider> output = [model predictionFromFeatures:input error:&error];

        if (error)
        {
            NSLog(@"Failed to execute face-swap model: %@", error);
            @throw error;
        }

        MLMultiArray *out_celebrity_face_data =
            [[output featureValueForName:@"out_celeb_face:0"] multiArrayValue];
        MLMultiArray *out_celebrity_face_mask_data =
            [[output featureValueForName:@"out_celeb_face_mask:0"] multiArrayValue];

        result->src_face = std::move(in_face);
        cv::Mat(224, 224, CV_32FC3, [out_celebrity_face_data dataPointer]).copyTo(result->dst_face);
        cv::Mat(224, 224, CV_32FC1, [out_celebrity_face_mask_data dataPointer])
            .copyTo(result->mask);
    }

    [input_provider release];
    [in_face_data release];

    return result;
}

void face_swap_impl::composite(cv::Mat &dst,
                               const face &extraction,
                               face2face **job,
                               const std::function<void(cv::Mat &)> callback)
{
    compositor_face2face face2face{
        .dst = dst,
        .extraction = extraction,
        .value = *job,
        .face2face_pool = &face2face_pool,
        .callback = callback,
    };

    if (!compositor_queue.try_push(face2face))
    {
        delete[] reinterpret_cast<uint8_t *>(dst.data);
        std::cout << "Failed to push image to compositor" << std::endl;
    }
}

std::unique_ptr<face_swap> face_swap::build(const fs::path &model_path, const fs::path &root_dir)
{
    std::vector<MLModel const *> model_pool = {
        load_model(model_path),
        load_model(model_path),
    };

    if (std::any_of(model_pool.begin(),
                    model_pool.end(),
                    [](MLModel const *model) { return model == nil; }))
        throw std::runtime_error("Failed to load all face-swap model instances");

    NSError *error = nil;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    std::string compositor_path = (root_dir / fs::path("face_compositor.metallib")).string();
    NSString *const compositor_pathstr = [NSString stringWithCString:compositor_path.c_str()
                                                            encoding:NSASCIIStringEncoding];
    NSURL *const compositor_url = [NSURL fileURLWithPath:compositor_pathstr];
    id<MTLLibrary> compositor = [device newLibraryWithURL:compositor_url error:&error];

    if (error)
    {
        NSLog(@"Failed to load Metal library: %@", error);
        return nil;
    }

    return std::unique_ptr<face_swap>(new face_swap_impl(model_pool, device, compositor));
}

} // namespace lens

@implementation CompositorThread

- (instancetype)initWithCompositor:compositor
                            device:device
                             queue:(oneapi::tbb::concurrent_bounded_queue<compositor_face2face> *)
                                       queue
{
    [super init];

    _compositor = compositor;
    _device = device;
    _queue = queue;

    _compositor_pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    [_compositor_pipeline_descriptor
        setVertexFunction:[compositor newFunctionWithName:@"vertex_main"]];
    [_compositor_pipeline_descriptor
        setFragmentFunction:[compositor newFunctionWithName:@"fragment_main"]];
    [[_compositor_pipeline_descriptor colorAttachments][0] setPixelFormat:MTLPixelFormatRGBA8Unorm];

    _compositor_state = [device newRenderPipelineStateWithDescriptor:_compositor_pipeline_descriptor
                                                               error:nil];

    return self;
}

- (void)main
{
    compositor_face2face wrapper;

    std::cout << "The compositor has started." << std::endl;

    while (![self isCancelled])
    {
        _queue->pop(wrapper);
        [self composite:&wrapper];
    }

    std::cout << "The compositor has unexpectedly terminated." << std::endl;
}

- (void)composite:(compositor_face2face *)wrapper
{
    cv::Mat dst = wrapper->dst;
    lens::face extraction = wrapper->extraction;
    lens::face2face *job = wrapper->value;
    oneapi::tbb::concurrent_queue<lens::face2face *> &face2face_pool = *wrapper->face2face_pool;
    std::function<void(cv::Mat &)> &callback = wrapper->callback;

    cv::Mat &face = job->src_face;
    cv::Mat &out_celeb_face = job->dst_face;
    cv::Mat &out_celeb_face_mask = job->mask;

    assert(dst.channels() == 4);
    assert(face.channels() == 3);
    assert(out_celeb_face.channels() == 3);
    assert(out_celeb_face_mask.channels() == 1);

    const int width = face.cols;
    const int height = face.rows;

    assert(width == 224 && out_celeb_face.cols == 224);
    assert(height == 224 && out_celeb_face.rows == 224);

    // Preprocessing
    out_celeb_face = lens::face_swap::color_transfer(out_celeb_face, face);
    cv::cvtColor(out_celeb_face, out_celeb_face, cv::COLOR_BGR2BGRA);

    id<MTLCommandQueue> command_queue = [_device newCommandQueue];

    auto *mask_descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                           width:width
                                                          height:height
                                                       mipmapped:false];
    auto *plane_descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                           width:width * 3
                                                          height:height * 3
                                                       mipmapped:false];
    auto *face_descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                           width:out_celeb_face.cols
                                                          height:out_celeb_face.rows
                                                       mipmapped:false];
    auto *frame_descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:dst.cols
                                                          height:dst.rows
                                                       mipmapped:false];
    mask_descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    face_descriptor.usage = MTLTextureUsageShaderRead;
    frame_descriptor.usage =
        MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;
    plane_descriptor.usage =
        MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;
    id<MTLTexture> mask_texture = [_device newTextureWithDescriptor:mask_descriptor];
    id<MTLTexture> plane0_texture = [_device newTextureWithDescriptor:plane_descriptor];
    id<MTLTexture> plane1_texture = [_device newTextureWithDescriptor:plane_descriptor];

    id<MTLTexture> face_texture = [_device newTextureWithDescriptor:face_descriptor];

    id<MTLTexture> in_texture = [_device newTextureWithDescriptor:frame_descriptor];
    id<MTLTexture> out_texture = [_device newTextureWithDescriptor:frame_descriptor];

    [mask_texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
                    mipmapLevel:0
                      withBytes:out_celeb_face_mask.data
                    bytesPerRow:out_celeb_face_mask.step[0]];
    [face_texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
                    mipmapLevel:0
                      withBytes:out_celeb_face.data
                    bytesPerRow:out_celeb_face.step[0]];
    [in_texture replaceRegion:MTLRegionMake2D(0, 0, dst.cols, dst.rows)
                  mipmapLevel:0
                    withBytes:dst.data
                  bytesPerRow:dst.step[0]];
    [out_texture replaceRegion:MTLRegionMake2D(0, 0, dst.cols, dst.rows)
                   mipmapLevel:0
                     withBytes:dst.data
                   bytesPerRow:dst.step[0]];

    const int radius = 6;
    MPSImageErode *erode = [[MPSImageErode alloc] initWithDevice:_device
                                                     kernelWidth:static_cast<NSUInteger>(3)
                                                    kernelHeight:static_cast<NSUInteger>(3)
                                                          values:NINE_ZEROS];
    MPSImageGaussianBlur *blur = [[MPSImageGaussianBlur alloc] initWithDevice:_device sigma:radius];

    @autoreleasepool
    {
        id<MTLCommandBuffer> command_buffer = [command_queue commandBuffer];

        auto mask_region = MTLRegionMake2D(0, 0, width, height);
        auto clip_region = MTLRegionMake2D(
            width + radius, height + radius, width - radius * 2, height - radius * 2);

        MTLRenderPassDescriptor *plane0_clear_descriptor =
            [MTLRenderPassDescriptor renderPassDescriptor];
        plane0_clear_descriptor.colorAttachments[0].texture = plane0_texture;
        plane0_clear_descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        plane0_clear_descriptor.colorAttachments[0].clearColor =
            MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        id<MTLRenderCommandEncoder> plane0_clear =
            [command_buffer renderCommandEncoderWithDescriptor:plane0_clear_descriptor];
        [plane0_clear endEncoding];

        auto *blit = [command_buffer blitCommandEncoder];
        [blit copyFromTexture:mask_texture
                  sourceSlice:0
                  sourceLevel:0
                 sourceOrigin:mask_region.origin
                   sourceSize:mask_region.size
                    toTexture:plane0_texture
             destinationSlice:0
             destinationLevel:0
            destinationOrigin:MTLOriginMake(width, height, 0)];
        [blit endEncoding];

        [erode encodeToCommandBuffer:command_buffer
                       sourceTexture:plane0_texture
                  destinationTexture:plane1_texture];
        [erode encodeToCommandBuffer:command_buffer
                       sourceTexture:plane1_texture
                  destinationTexture:plane0_texture];

        MTLRenderPassDescriptor *plane1_clear_descriptor =
            [MTLRenderPassDescriptor renderPassDescriptor];
        plane1_clear_descriptor.colorAttachments[0].texture = plane1_texture;
        plane1_clear_descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        plane1_clear_descriptor.colorAttachments[0].clearColor =
            MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        id<MTLRenderCommandEncoder> plane1_clear =
            [command_buffer renderCommandEncoderWithDescriptor:plane1_clear_descriptor];
        [plane1_clear endEncoding];

        auto *clip = [command_buffer blitCommandEncoder];
        [clip copyFromTexture:plane0_texture
                  sourceSlice:0
                  sourceLevel:0
                 sourceOrigin:clip_region.origin
                   sourceSize:clip_region.size
                    toTexture:plane1_texture
             destinationSlice:0
             destinationLevel:0
            destinationOrigin:clip_region.origin];
        [clip endEncoding];

        [blur encodeToCommandBuffer:command_buffer
                      sourceTexture:plane1_texture
                 destinationTexture:plane0_texture];

        MTLRenderPassDescriptor *render_pass_descriptor = [[MTLRenderPassDescriptor alloc] init];
        render_pass_descriptor.colorAttachments[0].texture = out_texture;
        render_pass_descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
        render_pass_descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        render_pass_descriptor.colorAttachments[0].clearColor =
            MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        const cv::Mat backwards_transform = extraction.transform.inv()(cv::Rect(0, 0, 3, 2));
        double a = backwards_transform.at<double>(0, 0);
        double b = backwards_transform.at<double>(0, 1);
        double tx = backwards_transform.at<double>(0, 2);
        double c = backwards_transform.at<double>(1, 0);
        double d = backwards_transform.at<double>(1, 1);
        double ty = backwards_transform.at<double>(1, 2);
        Vertex tl = {.dst_position = simd_make_float2(tx / dst.cols, ty / dst.rows),
                     .src_position = simd_make_float2(0, 0)};
        Vertex tr = {.dst_position =
                         simd_make_float2((a * width + tx) / dst.cols, (c * width + ty) / dst.rows),
                     .src_position = simd_make_float2(1, 0)};
        Vertex br = {.dst_position = simd_make_float2((a * width + b * height + tx) / dst.cols,
                                                      (c * width + d * height + ty) / dst.rows),
                     .src_position = simd_make_float2(1, 1)};
        Vertex bl = {.dst_position = simd_make_float2((b * height + tx) / dst.cols,
                                                      (d * height + ty) / dst.rows),
                     .src_position = simd_make_float2(0, 1)};

        Vertex vertices[6] = {tl, tr, br, br, bl, tl};
        id<MTLRenderCommandEncoder> render_encoder =
            [command_buffer renderCommandEncoderWithDescriptor:render_pass_descriptor];
        id<MTLBuffer> vertex_buffer =
            [_device newBufferWithBytes:vertices
                                 length:sizeof(vertices)
                                options:MTLResourceCPUCacheModeDefaultCache];
        MTLViewport viewport = {.originX = 0,
                                .originY = 0,
                                .width = static_cast<double>(dst.cols),
                                .height = static_cast<double>(dst.rows)};
        MTLSamplerDescriptor *sampler_descriptor = [[MTLSamplerDescriptor alloc] init];
        sampler_descriptor.minFilter = MTLSamplerMinMagFilterLinear;
        sampler_descriptor.magFilter = MTLSamplerMinMagFilterLinear;
        sampler_descriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
        sampler_descriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
        id<MTLSamplerState> sampler_state =
            [_device newSamplerStateWithDescriptor:sampler_descriptor];

        [render_encoder setRenderPipelineState:_compositor_state];
        [render_encoder setViewport:viewport];
        [render_encoder setCullMode:MTLCullModeNone];
        [render_encoder setVertexBuffer:vertex_buffer offset:0 atIndex:0];
        [render_encoder setFragmentTexture:in_texture atIndex:0];
        [render_encoder setFragmentSamplerState:sampler_state atIndex:0];
        [render_encoder setFragmentTexture:face_texture atIndex:1];
        [render_encoder setFragmentSamplerState:sampler_state atIndex:1];
        [render_encoder setFragmentTexture:mask_texture atIndex:2];
        [render_encoder setFragmentSamplerState:sampler_state atIndex:2];
        [render_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [render_encoder endEncoding];

        [command_buffer commit];
        [command_buffer waitUntilCompleted];

        [sampler_state release];
        [sampler_descriptor release];
        [render_pass_descriptor release];
        [vertex_buffer release];
    }

    // memset(dst.data, 0, dst.total()*dst.elemSize());

    [out_texture getBytes:dst.data
              bytesPerRow:dst.step[0]
               fromRegion:MTLRegionMake2D(0, 0, dst.cols, dst.rows)
              mipmapLevel:0];

    [erode release];
    [blur release];
    [out_texture release];
    [in_texture release];
    [face_texture release];
    [plane1_texture release];
    [plane0_texture release];
    [mask_texture release];
    [frame_descriptor release];
    [face_descriptor release];
    [plane_descriptor release];
    [mask_descriptor release];
    [command_queue release];

    face2face_pool.push(job);
    callback(dst);
}

@end // CompositorThread
