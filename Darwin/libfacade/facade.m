//
//  libfacade.m
//  libfacade
//
//  Created by Shukant Pal on 1/29/23.
//

#include "facade.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreMediaIO/CMIOHardware.h>
#import <os/log.h>

char *FACADE_MODEL = "Facade";
int FACADE_MODEL_LENGTH = 6;

CMIOObjectPropertyAddress kDeviceUIDProperty    = { kCMIODevicePropertyDeviceUID,
                                                    kCMIOObjectPropertyScopeGlobal,
                                                    kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kDeviceStreams        = { kCMIODevicePropertyStreams,
                                                    kCMIOObjectPropertyScopeGlobal,
                                                    kCMIOObjectPropertyElementMain };

CMIOObjectPropertyAddress kMagicProperty        = { 'fmag',
                                                    kCMIOObjectPropertyScopeGlobal,
                                                    kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kNameProperty         = { 'fnam',
                                                    kCMIOObjectPropertyScopeGlobal,
                                                    kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kDimensionsProperty   = { 'fdim',
                                                    kCMIOObjectPropertyScopeGlobal,
                                                    kCMIOObjectPropertyElementMain };
CMIOObjectPropertyAddress kFrameRateProperty    = { 'frat',
                                                    kCMIOObjectPropertyScopeGlobal,
                                                    kCMIOObjectPropertyElementMain };

CMIOObjectPropertyAddress kStateProperty        = { 'fsta',
                                                    kCMIOObjectPropertyScopeGlobal,
                                                    kCMIOObjectPropertyElementMain };

CFStringRef kPlugInBundleID = CFSTR("com.paalmaxima.Facade.Camera");
CMIOObjectID kPlugInID = 0;


int kIOStreamsPerDevice = 2;
int kWriteBufferCapacity = 100;

NSString *kMagicValue = @"Facade by Paal Maxima";

static os_log_t logger;

struct facade_device_data
{
    CMSimpleQueueRef read_queue;
    CMSimpleQueueRef write_queue;
    CMIOStreamID streams[2];
    CMVideoFormatDescriptionRef format_description;
    facade_callback read_callback;
    void *read_context;
    void *read_frame;
    facade_callback write_callback;
    void *write_context;
    CVPixelBufferPoolRef write_buffer_pool;
    CFDictionaryRef write_buffer_aux_attributes;
    CFMutableArrayRef write_sample_buffers;
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

static inline facade_error_code read_dimensions(facade_device *device)
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

    return facade_error_none;
}

static inline facade_error_code read_frame_rate(facade_device *device)
{
    if (!CMIOObjectHasProperty((CMIOObjectID) device->uid, &kFrameRateProperty)) {
        os_log_error(logger, "facade_device %lli - Frame rate property not found.",
                     device->uid);
        return facade_error_protocol;
    }

    UInt32 frame_rate_int_size = 0;
    CMIOObjectGetPropertyDataSize((CMIOObjectID) device->uid, &kFrameRateProperty,
                                  0, nil,
                                  &frame_rate_int_size);

    if (frame_rate_int_size != sizeof(uint32_t)) {
        os_log_error(logger,
                     "facade_device %lli - Frame rate property has unexpected byte size.",
                     device->uid);

        return facade_error_protocol;
    }

    CMIOObjectGetPropertyData((CMIOObjectID) device->uid, &kFrameRateProperty,
                              0, nil,
                              frame_rate_int_size, &frame_rate_int_size,
                              &device->frame_rate);

    return facade_error_none;
}

static inline facade_error_code read_format_description(facade_device *device)
{
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault,
                                   kCVPixelFormatType_32BGRA,
                                   device->width,
                                   device->height,
                                   nil,
                                   &device->data->format_description);
    return facade_error_none;
}

static inline facade_error_code create_write_buffer_pool(facade_device *device)
{
    uint32_t media_subtype = CMFormatDescriptionGetMediaSubType(device->data->format_description);

#define PIXEL_BUFFER_ATTRIBUTE_ENTRIES 4
    CFStringRef pixel_buffer_attribute_keys[PIXEL_BUFFER_ATTRIBUTE_ENTRIES] = {
        kCVPixelBufferWidthKey,
        kCVPixelBufferHeightKey,
        kCVPixelBufferPixelFormatTypeKey,
        kCVPixelBufferIOSurfacePropertiesKey,
    };
    CFTypeRef pixel_buffer_attribute_values[PIXEL_BUFFER_ATTRIBUTE_ENTRIES] =  {
        CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &device->width),
        CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &device->height),
        CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &media_subtype),
        CFDictionaryCreate(kCFAllocatorDefault,
                           nil,
                           nil,
                           0,
                           &kCFCopyStringDictionaryKeyCallBacks,
                           &kCFTypeDictionaryValueCallBacks)
    };
    CFDictionaryRef pixel_buffer_attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                                                 (const void **) pixel_buffer_attribute_keys,
                                                                 (const void **) pixel_buffer_attribute_values,
                                                                 PIXEL_BUFFER_ATTRIBUTE_ENTRIES,
                                                                 &kCFCopyStringDictionaryKeyCallBacks,
                                                                 &kCFTypeDictionaryValueCallBacks);
    CVPixelBufferPoolCreate(kCFAllocatorDefault,
                            nil,
                            pixel_buffer_attributes,
                            &device->data->write_buffer_pool);
    CFRelease(pixel_buffer_attributes);

#define BUFFER_AUX_ATTRIBUTE_ENTRIES 1
    CFStringRef aux_attribute_keys[BUFFER_AUX_ATTRIBUTE_ENTRIES] = { kCVPixelBufferPoolAllocationThresholdKey };
    CFTypeRef aux_attribute_values[BUFFER_AUX_ATTRIBUTE_ENTRIES] = { CFNumberCreate(kCFAllocatorDefault,
                                                                                    kCFNumberIntType,
                                                                                    &kWriteBufferCapacity) };
    device->data->write_buffer_aux_attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                                                   (const void **) aux_attribute_keys,
                                                                   (const void **) aux_attribute_values,
                                                                   BUFFER_AUX_ATTRIBUTE_ENTRIES,
                                                                   &kCFCopyStringDictionaryKeyCallBacks,
                                                                   &kCFTypeDictionaryValueCallBacks);
    
    return facade_error_none;
}

static inline facade_error_code release_write_buffer_pool(facade_device *device)
{
    if (device->data->write_buffer_pool == nil)
    {
        return facade_error_invalid_state;
    }
    
    CVPixelBufferPoolRelease(device->data->write_buffer_pool);
    CFRelease(device->data->write_buffer_aux_attributes);
    
    device->data->write_buffer_pool = nil;
    device->data->write_buffer_aux_attributes = nil;
    
    return facade_error_none;
}

facade_device *read_device(CMIOObjectID device_id)
{
    facade_device *device = calloc(1, sizeof(facade_device));
    device->type = facade_type_video;
    device->uid = device_id;
    device->data = calloc(1, sizeof(facade_device_data));
    device->data->write_sample_buffers = CFArrayCreateMutable(kCFAllocatorDefault, 6, &kCFTypeArrayCallBacks);

    UInt32 streamsArrayByteSize = 0;
    CMIOObjectGetPropertyDataSize(device_id, &kDeviceStreams,
                                  0, nil,
                                  &streamsArrayByteSize);
    UInt32 streamCount = streamsArrayByteSize / sizeof(CMIOStreamID);

    if (streamCount != kIOStreamsPerDevice) {
        os_log_error(logger,
                     "facade_device @%lli - Unexpected number of streams (%i vs %i)",
                     device->uid,
                     streamCount,
                     kIOStreamsPerDevice);

        free(device->data);
        free(device);

        return nil;
    } else {
        CMIOObjectGetPropertyData(device_id, &kDeviceStreams,
                                  0, nil,
                                  2 * sizeof(CMIOStreamID),
                                  &streamsArrayByteSize,
                                  &device->data->streams);
    }

    read_dimensions(device);
    read_frame_rate(device);
    read_format_description(device);

    return device;
}

facade_error_code facade_init(void)
{
    logger = os_log_create("com.paalmaxima.Facade", "FacadeKit");

    CMIOObjectPropertyAddress plugInForBundleIDProperty = {
        kCMIOHardwarePropertyPlugInForBundleID,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOHardwarePropertyPlugInForBundleID
    };

    UInt32 plugInIDByteSize = sizeof(kPlugInID);
    AudioValueTranslation translation = {
        .mInputData = &kPlugInBundleID,
        .mInputDataSize = sizeof(kPlugInBundleID),
        .mOutputData = &kPlugInID,
        .mOutputDataSize = sizeof(kPlugInID),
    };
    OSStatus result = CMIOObjectGetPropertyData(kCMIOObjectSystemObject,
                                                &plugInForBundleIDProperty,
                                                0, nil,
                                                sizeof(AudioValueTranslation),
                                                &plugInIDByteSize,
                                                &translation);

    return result == kCMIOHardwareNoError ? facade_error_none : facade_error_not_installed;
}

@interface FacadeStateXMLImport : NSObject <NSXMLParserDelegate>

- (facade_state*) import;

@end

@implementation FacadeStateXMLImport

facade_state *state;
facade_device_info *next_device;
NSString *tag;

- (facade_state *)import {
    return state;
}

- (void)parserDidStartDocument:(NSXMLParser *)parser {
    if (state == nil)
        state = calloc(1, sizeof(facade_state));
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict {
    
    tag = elementName;

    if ([elementName isEqualToString:@"video"]) {
        if (next_device == nil)
            next_device = calloc(1, sizeof(facade_device_info));
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (tag != nil && [tag isEqualToString:@"apiVersion"]) {
        char majorVersion = [string characterAtIndex:1] - '0';
        state->api_version = (facade_id) majorVersion;
    } else if (tag != nil && next_device != nil) {
        if ([tag isEqualToString:@"id"]) {
            next_device->uid = (facade_id) [string intValue];
        } else if ([tag isEqualToString:@"name"]) {
            next_device->name = calloc(1, [string length] + 1);
            strcpy(next_device->name, [string UTF8String]);
        } else if ([tag isEqualToString:@"width"]) {
            next_device->width = [string intValue];
        } else if ([tag isEqualToString:@"height"]) {
            next_device->height = [string intValue];
        } else if ([tag isEqualToString:@"frameRate"]) {
            next_device->frame_rate = [string intValue];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    tag = nil;

    if ([elementName isEqualToString:@"video"] && next_device != nil && state != nil) {
        if (state->devices == nil) {
            state->devices = next_device;
            next_device->next = next_device;
        } else {
            next_device->next = state->devices->next;
            state->devices->next = next_device;
        }
        
        next_device = nil;
    }
}

@end

facade_error_code facade_read_state(facade_state **state)
{
    if (kPlugInID == 0) return facade_error_not_initialized;

    OSStatus result = kCMIOHardwareNoError;

    UInt32 stateValueByteSize = 0;
    result = CMIOObjectGetPropertyDataSize(kPlugInID, &kStateProperty,
                                           0, nil,
                                           &stateValueByteSize);
    char *stateValue = calloc(stateValueByteSize, sizeof(char));
    result = CMIOObjectGetPropertyData(kPlugInID, &kStateProperty,
                                       0, nil,
                                       stateValueByteSize, &stateValueByteSize,
                                       stateValue);

    FacadeStateXMLImport *importer = [[FacadeStateXMLImport alloc] init];
    
    @autoreleasepool {
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[NSData dataWithBytes:stateValue length:stateValueByteSize]];
        parser.delegate = importer;
        [parser parse];
    }
    
    *state = importer.import;

    return result == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}

facade_error_code facade_list_devices(facade_device **list)
{
    CMIOObjectPropertyAddress devicesPropertyAddress = {
        kCMIOHardwarePropertyDevices,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMain
    };

    UInt32 deviceArrayByteSize = 0;
    CMIOObjectGetPropertyDataSize(kCMIOObjectSystemObject,
                                  &devicesPropertyAddress,
                                  0, NULL,
                                  &deviceArrayByteSize);

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
    
    return facade_error_none;
}

void on_read_queue_ready(CMIOStreamID _, void *__, void *device)
{
    facade_device_data *data = ((facade_device *) device)->data;
    if (data->read_callback != nil)
        (*data->read_callback)(data->read_context);
}

facade_error_code facade_read_open(facade_device *device)
{
    if (device->data->read_queue != nil) {
        os_log_error(logger,
                     "facade_read_open %lli - Input stream is already open.",
                     device->uid);
        return facade_error_invalid_state;
    }
    
    device->data->read_callback = nil;
    device->data->read_context = nil;
    
    OSStatus status = CMIODeviceStartStream((CMIODeviceID) device->uid, device->data->streams[0]);

    if (status != kCMIOHardwareNoError) {
        os_log_error(logger,
                     "facade_read_open %lli - Input stream failed to open.",
                     device->uid);
        return facade_error_unknown;
    }

    status = CMIOStreamCopyBufferQueue(device->data->streams[0],
                                       &on_read_queue_ready,
                                       device,
                                       &device->data->read_queue);
    
    if (status != kCMIOHardwareNoError) {
        os_log_error(logger,
                     "facade_read_open %lli - Input buffer queue could not be copied",
                     device->uid);
        return facade_error_unknown;
    }

    return facade_error_none;
}

facade_error_code facade_read_frame(facade_device *device, void **buffer, size_t *buffer_size)
{
    if (device->data->read_queue == nil)
        return facade_error_reader_not_ready;

    OSStatus status = kCMIOHardwareNoError;

    CMSampleBufferRef sample_buffer =
        (CMSampleBufferRef) CMSimpleQueueDequeue(device->data->read_queue);

    if (sample_buffer == nil) {
#if DEBUG
        os_log_error(logger,
                     "facade_read_frame %lli - Input stream has no frames left.",
                     device->uid);
#endif
        return facade_error_reader_not_ready;
    }

    CVImageBufferRef image_buffer = CMSampleBufferGetImageBuffer(sample_buffer);
    CVPixelBufferLockBaseAddress(image_buffer, 0);

    char *data = CVPixelBufferGetBaseAddress(image_buffer);
    size_t data_length = CVPixelBufferGetDataSize(image_buffer);

    if (data_length < device->width * device->height * BYTES_PER_PIXEL) {
        os_log_error(logger,
                     "facade_read_frame %lli - Receive buffer has wrong size (%li). (OSStatus %i)",
                     device->uid,
                     data_length,
                     status);
        return facade_error_unknown;
    }

    if (device->data->read_frame == nil)
        device->data->read_frame = malloc(data_length);

    memcpy(device->data->read_frame, data, data_length);

    CVPixelBufferUnlockBaseAddress(image_buffer, 0);
    CFRelease(sample_buffer);

    *buffer = device->data->read_frame;
    *buffer_size = data_length;

    return facade_error_none;
}

facade_error_code facade_read_close(facade_device *device)
{
    OSStatus status = CMIODeviceStopStream((CMIODeviceID) device->uid, device->data->streams[0]);
 
    if (device->data->read_queue != nil)
    {
        CFRelease(device->data->read_queue);
        device->data->read_queue = nil;
    }

    return status == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}

void on_write_queue_ready(CMIOStreamID _, void *__, void *device)
{
    facade_device_data *data = ((facade_device *) device)->data;

    if (data->write_callback != nil)
        (*data->write_callback)(data->write_context);
}

facade_error_code facade_write_open(facade_device *device)
{
    if (device->data->write_queue != nil) {
        os_log_error(logger,
                     "facade_write_open %lli - Output stream is already open.",
                     device->uid);
        return facade_error_invalid_state;
    }
    
    OSStatus status = CMIODeviceStartStream((CMIODeviceID) device->uid, device->data->streams[1]);

    if (status != kCMIOHardwareNoError) {
        os_log_error(logger,
                     "facade_write_open %lli - Output stream failed to open.",
                     device->uid);
        return facade_error_unknown;
    }

    status = CMIOStreamCopyBufferQueue(device->data->streams[1],
                                       &on_write_queue_ready,
                                       device,
                                       &device->data->write_queue);

    if (status != kCMIOHardwareNoError) {
        os_log_error(logger,
                     "facade_write_open %lli - Output buffer queue could not be copied.",
                     device->uid);
        return facade_error_unknown;
    }

    return facade_error_none;
}

facade_error_code facade_write_callback(facade_device *device, facade_callback callback, void *context)
{
    device->data->write_callback = callback;
    device->data->write_context = context;
    
    return facade_error_none;
}

facade_error_code facade_write_frame(facade_device *device, void *buffer, size_t buffer_size)
{
    if (device->data->write_queue == nil) {
        os_log_error(logger,
                     "facade_write_frame %lli - Output stream was not opened.",
                     device->uid);
        return facade_error_writer_not_ready;
    }
    if (buffer_size < BYTES_PER_PIXEL * device->width * device->height) {
        os_log_error(logger,
                     "facade_write_frame %lli - Send buffer has wrong size. (%li vs %li)",
                     device->uid,
                     buffer_size,
                     (size_t) BYTES_PER_PIXEL * device->width * device->height);
        return facade_error_invalid_input;
    }
    if (device->data->write_buffer_pool == nil) {
#if DEBUG
        os_log_debug(logger,
                     "facade_write_frame %lli - Allocating write buffer pool",
                     device->uid);
#endif
        create_write_buffer_pool(device);
    }

    OSStatus status = kCMIOHardwareNoError;

    CMSampleTimingInfo timingInfo = { };
    timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock());
    CMSampleBufferRef sample_buffer;
    CVPixelBufferRef pixel_buffer;
    CVReturn success = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault,
                                                                           device->data->write_buffer_pool,
                                                                           device->data->write_buffer_aux_attributes,
                                                                           &pixel_buffer);
    if (success != kCVReturnSuccess) {
        os_log_error(logger,
                     "facade_write_frame %lli - Failed to allocate pixel buffer. (OSStatus %i)",
                     device->uid,
                     success);
        return facade_error_unknown;
    }

    CVPixelBufferLockBaseAddress(pixel_buffer, 0);
    memcpy(CVPixelBufferGetBaseAddress(pixel_buffer),
           buffer,
           (size_t) BYTES_PER_PIXEL * device->width * device->height);
    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);

    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                                pixel_buffer,
                                                true,
                                                nil, nil,
                                                device->data->format_description,
                                                &timingInfo,
                                                &sample_buffer);
    if (status != kCMBlockBufferNoErr) {
        os_log_error(logger,
                     "facade_write_frame %lli - Failed to create sample buffer. (OSStatus %i)",
                     device->uid,
                     status);
        CFRelease(sample_buffer);
        CVPixelBufferRelease(pixel_buffer);

        return facade_error_unknown;
    }

    status = CMSimpleQueueEnqueue(device->data->write_queue, sample_buffer);
    
    if (status != kCMBlockBufferNoErr) {
        os_log_error(logger,
                     "facade_write_frame %lli - Failed to queue frame. (OSStatus %i)",
                     device->uid,
                     status);
    }
    
    CVPixelBufferRelease(pixel_buffer);

    return status == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}

facade_error_code facade_write_close(facade_device *device)
{
    OSStatus status = CMIODeviceStopStream((CMIODeviceID) device->uid, device->data->streams[1]);

    if (device->data->write_queue != nil)
    {
        CFRelease(device->data->write_queue);
        device->data->write_queue = nil;
    }

    return status == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}
