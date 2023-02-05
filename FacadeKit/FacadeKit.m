//
//  FacadeKit.cpp
//  FacadeKit
//
//  Created by Shukant Pal on 1/29/23.
//

#include "FacadeKit.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreMediaIO/CMIOHardware.h>
#import <os/log.h>

char *FACADE_MODEL = "Facade";
int FACADE_MODEL_LENGTH = 6;

CMIOObjectPropertyAddress kDeviceUIDProperty    = { kCMIODevicePropertyDeviceUID, kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kDeviceStreams        = { kCMIODevicePropertyStreams,   kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kMagicProperty        = { 'fmag',                       kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kNameProperty         = { 'fnam',                       kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kDimensionsProperty   = { 'fdim',                       kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kFrameRateProperty    = { 'frat',                       kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };

NSString *kMagicValue = @"Facade by Paal Maxima";

static os_log_t logger;

struct facade_device_data
{
    CMSimpleQueueRef read_queue;
    CMSimpleQueueRef write_queue;
    CMIOStreamID streams[2];
    CMVideoFormatDescriptionRef formatDescription;
    facade_read_callback read_callback;
    void *read_context;
    void *read_frame;
    facade_write_callback write_callback;
    void *write_context;
    CVPixelBufferPoolRef pixel_buffer_pool;
    CFDictionaryRef bux_aux_attributes;
};

void insert_device(facade_device **list, facade_device *node)
{
    if (*list == nil) {
        *list = node;
        node->next = node;
    } else { // insert after list head and shift
        node->next = (*list)->next;
        (*list)->next = node;
        *list = node;
    }
}

void facade_init_device_dimensions(facade_device *device)
{
    UInt32 dimensions_string_length = 0;
    CMIOObjectGetPropertyDataSize((CMIOObjectID) device->uid, &kDimensionsProperty,
                                  0, nil,
                                  &dimensions_string_length);
    char *dimensions = malloc(dimensions_string_length);
    CMIOObjectGetPropertyData((CMIOObjectID) device->uid, &kDimensionsProperty,
                              0, nil,
                              dimensions_string_length, &dimensions_string_length,
                              dimensions);
    printf("%i dimensions length\n", dimensions_string_length);
    NSScanner *scanner = [NSScanner scannerWithString:[NSString stringWithUTF8String:dimensions]];

    int temp_width = 0, temp_height = 0;
    [scanner scanInt:&temp_width];
    [scanner scanString:@"x" intoString:NULL];
    [scanner scanInt:&temp_height];

    if (device->width != temp_width || device->height != temp_height) {
        device->width = temp_width;
        device->height = temp_height;

        if (device->data->read_frame != nil) {
            free(device->data->read_frame);
            device->data->read_frame = nil;
        }
    }
    
    free(dimensions);
    
#if DEBUG
    os_log_debug(logger, "facade_device@%lli - parsed dimensions %i x %i\n",
                 device->uid, device->width, device->height);
#endif
}

facade_error_code facade_init_device_frame_rate(facade_device *device)
{
    if (!CMIOObjectHasProperty((CMIOObjectID) device->uid, &kFrameRateProperty)) {
#if DEBUG
        os_log_debug(logger, "facade_device@%lli - failed to parse frame rate because property does not exist",
                     device->uid);
        return facade_error_protocol;
#endif
    }
    
    UInt32 frame_rate_int_size = 0;
    CMIOObjectGetPropertyDataSize((CMIOObjectID) device->uid, &kFrameRateProperty,
                                  0, nil,
                                  &frame_rate_int_size);
    
    if (frame_rate_int_size != sizeof(uint32_t)) {
#if DEBUG
        os_log_debug(logger, "facade_device@%lli - failed to parse frame rate because data size is %i not %i\n",
                     device->uid, frame_rate_int_size, (int) sizeof(uint32_t));
#endif
        return facade_error_protocol;
    }

    CMIOObjectGetPropertyData((CMIOObjectID) device->uid, &kFrameRateProperty,
                              0, nil,
                              frame_rate_int_size, &frame_rate_int_size,
                              &device->frame_rate);
    
#if DEBUG
    os_log_debug(logger, "facade_device@%lli - parsed frame rate %i\n",
                 device->uid, device->frame_rate);
#endif

    return facade_error_none;
}

facade_device *read_device(CMIOObjectID device_id)
{
    facade_device *device = malloc(sizeof(facade_device));

    device->next = nil;
    device->type = video_facade;
    device->uid = device_id;
    device->width = 0;
    device->height = 0;
    device->frame_rate = 0;
    device->data = malloc(sizeof(facade_device_data));
    device->data->read_queue = nil;
    device->data->write_queue = nil;
    
    UInt32 streamsArrayByteSize = 0;
    CMIOObjectGetPropertyDataSize(device_id, &kDeviceStreams,
                                  0, nil,
                                  &streamsArrayByteSize);
    UInt32 streamCount = streamsArrayByteSize / sizeof(CMIOStreamID);

    if (streamCount != 2) {
        printf("Unexpected number of streams (%i)!", streamCount);
        free(device);
        return nil;
    } else {
        CMIOObjectGetPropertyData(device_id, &kDeviceStreams,
                                  0, nil,
                                  2 * sizeof(CMIOStreamID),
                                  &streamsArrayByteSize,
                                  &device->data->streams);
    }

    // Parse dimensions
    facade_init_device_dimensions(device);
    facade_init_device_frame_rate(device);
    
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCVPixelFormatType_32BGRA,
                                   device->width, device->height, nil,
                                   &device->data->formatDescription);
    uint32_t media_subtype = CMFormatDescriptionGetMediaSubType(device->data->formatDescription);
    const void *keys[3] = {
        kCVPixelBufferWidthKey,
        kCVPixelBufferHeightKey,
        kCVPixelBufferPixelFormatTypeKey,
    };
    
    CFNumberRef widthRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &device->width);
    CFNumberRef heightRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &device->height);
    CFNumberRef mediaSubtypeRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &media_subtype);
    CFNumberRef values[3] =  {
        widthRef,
        heightRef,
        mediaSubtypeRef
    };
    CFDictionaryRef pixelBufferAttributes = CFDictionaryCreate(kCFAllocatorDefault,
                       keys,
                       (const void **) values,
                       3,
                       &kCFCopyStringDictionaryKeyCallBacks,
                       &kCFTypeDictionaryValueCallBacks);
    CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &device->data->pixel_buffer_pool);
    CFRelease(pixelBufferAttributes);
    
    const void *keys2[1] = {
        kCVPixelBufferPoolAllocationThresholdKey
    };
    int threshold = 100;
    CFNumberRef thresholdRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &threshold);
    CFNumberRef values2[1] = {
        thresholdRef
    };
    
    device->data->bux_aux_attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                                          keys2,
                                                          (const void **) values2,
                                                          0,
                                                          &kCFCopyStringDictionaryKeyCallBacks,
                                                          &kCFTypeDictionaryValueCallBacks);
    
    return device;
}

void facade_init(void)
{
    logger = os_log_create("com.paalmaxima.Facade", "FacadeKit");
}

void facade_list_devices(facade_device **list)
{
    // kCMIOObjectSystemObject is the system CMIO object that will be used to get a list of device ids.
    CMIOObjectPropertyAddress devicesPropertyAddress = {
        kCMIOHardwarePropertyDevices,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMain
    };

    UInt32 deviceArrayByteSize = 0;
    CMIOObjectGetPropertyDataSize(kCMIOObjectSystemObject, &devicesPropertyAddress, 0, NULL, &deviceArrayByteSize);

    CMIOObjectID *deviceIds = (CMIOObjectID *) malloc(deviceArrayByteSize);
    UInt32 deviceArrayByteSizedUsed = 0; // should match deviceArrayByteSize
    CMIOObjectGetPropertyData(kCMIOObjectSystemObject,
                              &devicesPropertyAddress,
                              0,
                              NULL,
                              deviceArrayByteSize,
                              &deviceArrayByteSizedUsed,
                              deviceIds);

    UInt32 deviceCount = deviceArrayByteSizedUsed / sizeof(CMIOObjectID);

#if DEBUG
    printf("Found %i CoreMediaIO devices on system\n", deviceCount);
#endif

    for (UInt32 i = 0; i < deviceCount; i++)
    {
        bool hasMagicProperty = CMIOObjectHasProperty(deviceIds[i], &kMagicProperty);
        if (!hasMagicProperty)
            continue;

        UInt32 magicValueLength = 0;
        CMIOObjectGetPropertyDataSize(deviceIds[i], &kMagicProperty, 0, nil, &magicValueLength);
        if (magicValueLength != kMagicValue.length + 1)
            continue;

        char *magicValueBuffer = malloc(magicValueLength);
        CMIOObjectGetPropertyData(deviceIds[i], &kMagicProperty,
                                  0, nil,
                                  magicValueLength, &magicValueLength, magicValueBuffer);
        if ([kMagicValue isEqualToString:[NSString stringWithUTF8String:magicValueBuffer]])
        {
            facade_device *device = read_device(deviceIds[i]);

            if (device != nil)
                insert_device(list, device);
        }

        free(magicValueBuffer);
    }
}

void facade_read_altered_callback(CMIOStreamID _, void *__, void *device)
{
    facade_device_data *data = ((facade_device *) device)->data;
    
    printf("read_callback\n");

    if (data->read_callback != nil)
        (*data->read_callback)(data->read_context);
}

facade_error_code facade_reader(facade_device *device, facade_read_callback callback, void *context)
{
    OSStatus status = CMIOStreamCopyBufferQueue(device->data->streams[0],
                                                &facade_read_altered_callback,
                                                device,
                                                &device->data->read_queue);
    
    device->data->read_callback = callback;
    device->data->read_context = context;
    CMIOObjectShow(device->data->streams[0]);
    CMIOObjectShow(device->data->streams[1]);
    printf("HERER\n");
    
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo])
    {
        case AVAuthorizationStatusAuthorized:
        {
            printf("Authorized");
            // The user has previously granted access to the camera.
            
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            printf("NOtDetermined");
            // The app hasn't yet asked the user for camera access.
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    printf("Granted");
                }
            }];
            break;
        }
        case AVAuthorizationStatusDenied:
        {
            printf("Denied");
            // The user has previously denied access.
            break;
        }
        case AVAuthorizationStatusRestricted:
        {
            printf("Restriction");
            // The user can't grant access due to restrictions.
            break;
        }
    }

    return status != kCMIOHardwareNoError ? facade_error_unknown : facade_error_none;
}

facade_error_code facade_read(facade_device *device, void **buffer, size_t *buffer_size)
{
    if (device->data->read_queue == nil)
        return facade_error_reader_not_ready;

    OSStatus status = kCMIOHardwareNoError;

    status = CMIODeviceStartStream((CMIODeviceID) device->uid, device->data->streams[0]);
    if (status != kCMIOHardwareNoError) {
        os_log_error(logger,
                     "facade_device@%lli - Failed to start stream on device.",
                     device->uid);
        return facade_error_unknown;
    }

    CMSampleBufferRef sample_buffer = (CMSampleBufferRef) CMSimpleQueueDequeue(device->data->read_queue);
    
    if (sample_buffer == nil) {
        os_log_error(logger, "null sample_buffer");
        return facade_error_reader_not_ready;
    }
    
    CVImageBufferRef image_buffer = CMSampleBufferGetImageBuffer(sample_buffer);

    
    if (image_buffer == nil) {
        os_log_error(logger,
                    "facade_device@%lli - Image buffer is null",
                    device->uid);
        
        return facade_error_reader_not_ready;
    }
    
    CVPixelBufferLockBaseAddress(image_buffer, 0);
    char *data = CVPixelBufferGetBaseAddress(image_buffer);
    size_t data_length = CVPixelBufferGetDataSize(image_buffer);
    status = kCMIOHardwareNoError;
   
    if (status != kCMBlockBufferNoErr) {
        os_log_error(logger,
                     "facade_device@%lli - Failed to get data pointer to block buffer containing pixel data. (OSStatus %i)",
                     device->uid,
                     status);
        return facade_error_unknown;
    }
    if (data_length < device->width * device->height * BYTES_PER_PIXEL) {
        os_log_error(logger,
                     "facade_device@%lli - The byte size of the recieved frame is an unexpected value (%li). (OSStatus %i)",
                     device->uid,
                     data_length,
                     status);
    }

    if (device->data->read_frame == nil)
        device->data->read_frame = malloc(device->width * device->height * BYTES_PER_PIXEL);
    memcpy(device->data->read_frame, data, device->width * device->height * BYTES_PER_PIXEL);

    *buffer = device->data->read_frame;
    *buffer_size = data_length;
    CVPixelBufferUnlockBaseAddress(image_buffer, 0);
    
    CFRelease(sample_buffer);

    return facade_error_none;
}

void facade_write_altered_callback(CMIOStreamID _, void *__, void *device)
{
    printf("here5");
    facade_device_data *data = ((facade_device *) device)->data;

    if (data->write_callback != nil)
        (*data->write_callback)(data->write_context);

    printf("here6");
}

facade_error_code facade_writer(facade_device *device, facade_write_callback callback, void *context)
{
    OSStatus status = CMIOStreamCopyBufferQueue(device->data->streams[1],
                                                &facade_write_altered_callback,
                                                device,
                                                &device->data->write_queue);
    
    device->data->write_callback = callback;
    device->data->write_context = context;
    
    return status != kCMIOHardwareNoError ? facade_error_unknown : facade_error_none;
}

facade_error_code facade_write(facade_device *device, void *buf, size_t buffer_size)
{
    if (device->data->write_queue == nil)
        return facade_error_writer_not_ready;
    
    OSStatus status = kCMIOHardwareNoError;
    
    if (status != kCMIOHardwareNoError) {
        return facade_error_unknown;
    }
    
    printf("here2");
    status = CMIODeviceStartStream((CMIODeviceID) device->uid, device->data->streams[1]);
    
    if (status != kCMIOHardwareNoError) {
        return facade_error_unknown;
    }
    printf("here3");
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCVPixelFormatType_32BGRA,
                                   1920, 1080, nil,
                                   &device->data->formatDescription);
    CMSampleTimingInfo timingInfo = { };
    timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock());
    CMSampleBufferRef sbuffer;
    
    NSDictionary *pixelAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}};
    CVPixelBufferRef pixelBuffer;
    CVReturn success = CVPixelBufferCreate(kCFAllocatorDefault,
                                           1920, 1080, k32BGRAPixelFormat,
                                           (__bridge CFDictionaryRef)(pixelAttributes), &pixelBuffer);
    
    printf("%i\n", success);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    memcpy(CVPixelBufferGetBaseAddress(pixelBuffer), buf, 4 * 1920 * 1080);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                       pixelBuffer,
                                       true,
                                       nil, nil,
                                       device->data->formatDescription,
                                       &timingInfo,
                                       &sbuffer);
    status = CMSimpleQueueEnqueue(device->data->write_queue, sbuffer);
    
    CFRelease(pixelBuffer);
    printf("here4");
    
    return status == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}
