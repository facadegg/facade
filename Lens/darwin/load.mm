
#include "lens.h"

#include <string>

#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

namespace
{

void load_frame(CVPixelBufferRef pixel_buffer, lens::face_pipeline& pipeline)
{
    CVPixelBufferLockBaseAddress(pixel_buffer, kCVPixelBufferLock_ReadOnly);

    void *base_address = CVPixelBufferGetBaseAddress(pixel_buffer);
    size_t bytes_per_row = CVPixelBufferGetBytesPerRow(pixel_buffer);
    size_t width = CVPixelBufferGetWidth(pixel_buffer);
    size_t height = CVPixelBufferGetHeight(pixel_buffer);

    size_t pixels_count = width * height;
    auto *image_buffer = new uint8_t[pixels_count * 4];

    const vImage_Buffer src {
        .data = base_address,
        .height = height,
        .width = width,
        .rowBytes = bytes_per_row,
    };
    const vImage_Buffer dst {
        .data = image_buffer,
        .height = height,
        .width = width,
        .rowBytes = 4 * width,
    };
    vImageCopyBuffer(&src, &dst, 4, kvImageNoAllocate);

    CVPixelBufferUnlockBaseAddress(pixel_buffer, kCVPixelBufferLock_ReadOnly);

    cv::Mat image(static_cast<int>(height),
                  static_cast<int>(width),
                  CV_8UC4,
                  image_buffer);
    pipeline << image;
}

} // namespace

@interface CaptureDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic) lens::face_pipeline* pipeline;

- (instancetype)init:(lens::face_pipeline *)pipeline;

@end

@implementation CaptureDelegate

- (instancetype)init:(lens::face_pipeline *)pipeline {
    self = [super init];
    if (self) {
        _pipeline = pipeline;
    }
    return self;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVPixelBufferRef pixel_buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    load_frame(pixel_buffer, *_pipeline);
}

@end

namespace
{

std::vector<std::string> image_formats = {"jpg", "jpeg", "png", "gif", "bmp"};
std::vector<std::string> video_formats = {"mp4", "mov", "avi", "mkv", "wmv"};

bool match(const std::vector<std::string>& formats, const std::string& path)
{
    for (auto it = formats.begin(); it != formats.end(); ++it)
        if (path.ends_with(*it))
            return true;

    return false;
}

bool load_camera(NSString* src, lens::face_pipeline& pipeline)
{
    auto* discovery_session = [AVCaptureDeviceDiscoverySession
            discoverySessionWithDeviceTypes:src != nil ?
                                            @[AVCaptureDeviceTypeBuiltInWideAngleCamera,
                                              AVCaptureDeviceTypeExternalUnknown] :
                                            @[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                  mediaType:AVMediaTypeVideo
                                   position:AVCaptureDevicePositionUnspecified];
    auto* devices = discovery_session.devices;
    AVCaptureDevice *src_device = nil;

    for (AVCaptureDevice* device in devices) {
        if (src == nil || [device.uniqueID isEqualToString:src]) {
            src_device = device;
            break;
        }
    }

    if (src_device == nil) {
        return false;
    }

    NSError *input_error = nil;
    auto *input = [AVCaptureDeviceInput deviceInputWithDevice:src_device error:&input_error];

    if (input_error != nil) {
        NSLog(@"There was a problem capturing the source device (code %ld): %@.",
              static_cast<long>(input_error.code),
              input_error.localizedDescription);
        return false;
    }

    AVCaptureVideoDataOutput* output = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary* output_settings = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    };
    dispatch_queue_t output_queue = dispatch_queue_create("FrameTaker", DISPATCH_QUEUE_SERIAL);
    auto* output_delegate = [[CaptureDelegate alloc] init:&pipeline];
    [output setVideoSettings:output_settings];
    [output setSampleBufferDelegate:output_delegate queue:output_queue];

    auto* session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetHigh;
    if (![session canAddInput:input] || ![session canAddOutput:output]) {
        [output_delegate release];
        [output release];
        [session release];
        NSLog(@"There was a problem setting up input/output on the device capture session.");
        return false;
    }
    [session addInput:input];
    [session addOutput:output];
    [session commitConfiguration];
    [session startRunning];

    std::this_thread::sleep_for(std::chrono::hours::max());
    std::cout << "The video capture thread has unexpectedly ended" << std::endl;

    [output_delegate release];
    [output release];
    [session release];

    return true;
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

    if (result != kCVReturnSuccess)
    {
        std::cout << "There was an error opening the buffer " <<  result << std::endl;
    }

    [context render:image toCVPixelBuffer:pixel_buffer];

    load_frame(pixel_buffer, pipeline);

    CVPixelBufferRelease(pixel_buffer);
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
        return false;
    }

    return load_camera(cxx_path.empty() ? nil : path, pipeline);;
}

} // namespace lens