//
//  FacadeKit.cpp
//  FacadeKit
//
//  Created by Shukant Pal on 1/29/23.
//

#include "FacadeKit.h"
#import <CoreMedia/CoreMedia.h>
#import <CoreMediaIO/CMIOHardware.h>

char *FACADE_MODEL = "Facade";
int FACADE_MODEL_LENGTH = 6;

CMIOObjectPropertyAddress kDeviceUIDProperty =  { kCMIODevicePropertyDeviceUID, kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kDeviceStreams =      { kCMIODevicePropertyStreams,   kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kMagicProperty =      { 'fmag',                       kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kNameProperty =       { 'fnam',                       kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kDimensionsProperty = { 'fdim',                       kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain };

NSString *kMagicValue = @"Facade by Paal Maxima";

struct facade_device_data
{
    CMSimpleQueueRef queue;
    CMIOStreamID streams[2];
    CMVideoFormatDescriptionRef formatDescription;
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

facade_device *read_device(CMIOObjectID device_id)
{
    facade_device *device = malloc(sizeof(facade_device));

    device->next = nil;
    device->type = video_facade;
    device->uid = device_id;
    device->data = malloc(sizeof(facade_device_data));
    device->data->queue = nil;
    
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
    
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCVPixelFormatType_32BGRA,
                                   1920, 1080, nil,
                                   &device->data->formatDescription);
    uint32_t media_subtype = CMFormatDescriptionGetMediaSubType(device->data->formatDescription);
    const void *keys[3] = {
        kCVPixelBufferWidthKey,
        kCVPixelBufferHeightKey,
        kCVPixelBufferPixelFormatTypeKey,
    };
    
    static int w = 1920;
    static int h = 1080;
    
    CFNumberRef widthRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &w);
    CFNumberRef heightRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &h);
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

void facade_write_altered_callback(CMIOStreamID _, void *__, void *device)
{
    printf("here5");
    facade_device_data *data = ((facade_device *) device)->data;

    if (data->write_callback != nil) {
        (*data->write_callback)(data->write_context);
    }
    printf("here6");
}

facade_error_code facade_write(facade_device *device, void *buf, facade_write_callback callback, void *context)
{
    device->data->write_callback = callback;
    device->data->write_context = context;
    
    printf("here1");
    OSStatus status = CMIOStreamCopyBufferQueue(device->data->streams[1],
                                                &facade_write_altered_callback,
                                                device,
                                                &device->data->queue);
    
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
    status = CMSimpleQueueEnqueue(device->data->queue, sbuffer);
    
    CFRelease(pixelBuffer);
    printf("here4");
    
    return status == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}
