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

CMIOObjectPropertyAddress kDeviceIDsProperty = {
    kCMIOHardwarePropertyDevices, kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};

CMIOObjectPropertyAddress kDeviceNameProperty = {
    kCMIOObjectPropertyName, kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};
CMIOObjectPropertyAddress kDeviceStreams = {
    kCMIODevicePropertyStreams, kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};

CMIOObjectPropertyAddress kMagicProperty = {
    'fmag', kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};
CMIOObjectPropertyAddress kUIDProperty = {
    'fuid', kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};
CMIOObjectPropertyAddress kNameProperty = {
    'fnam', kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};
CMIOObjectPropertyAddress kDimensionsProperty = {
    'fdim', kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};
CMIOObjectPropertyAddress kFrameRateProperty = {
    'frat', kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};

CMIOObjectPropertyAddress kStateProperty = {
    'fsta', kCMIOObjectPropertyScopeGlobal, kCMIOObjectPropertyElementMain};

CFStringRef kPlugInBundleID = CFSTR("gg.facade.Facade.Camera");
CMIOObjectID kPlugInID = 0;

int kIOStreamsPerDevice = 2;
int kWriteBufferCapacity = 100;

NSString *kMagicValue = @"Facade by Paal Maxima";

facade_callback state_changed_callback = nil;
void *state_changed_context = nil;
CMIOObjectPropertyListenerBlock state_changed_block = nil;

dispatch_queue_t listener_queue;

static os_log_t logger;

struct facade_device_data
{
    CMIOObjectID cmio_id;
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
    facade_callback changed_callback;
    void *changed_context;
    CMIOObjectPropertyListenerBlock changed_block;
};

void insert_device(facade_device **list, facade_device *node)
{
    if (*list == nil)
    {
        *list = node;
        node->next = node;
    }
    else
    { // insert after list head and shift
        node->next = (*list)->next;
        (*list)->next = node;
        *list = node;
    }
}

void insert_device_info(facade_device_info **list, facade_device_info *node)
{
    if (*list == nil)
    {
        *list = node;
        node->next = node;
    }
    else
    { // insert after list head and shift
        node->next = (*list)->next;
        (*list)->next = node;
        *list = node;
    }
}

void dispose_device_info(facade_device_info **node_ref)
{
    facade_device_info *node = *node_ref;

    if (node->uid != nil)
        free((void *)node->uid);
    if (node->name != nil)
        free((void *)node->name);

    free(node);
    *node_ref = nil;
}

static inline void list_devices(CMIOObjectID **device_ids, UInt32 *device_count)
{
    UInt32 device_ids_byte_size = 0;
    CMIOObjectGetPropertyDataSize(
        kCMIOObjectSystemObject, &kDeviceIDsProperty, 0, NULL, &device_ids_byte_size);

    *device_ids = (CMIOObjectID *)malloc(device_ids_byte_size);
    CMIOObjectGetPropertyData(kCMIOObjectSystemObject,
                              &kDeviceIDsProperty,
                              0,
                              NULL,
                              device_ids_byte_size,
                              &device_ids_byte_size,
                              *device_ids);

    *device_count = device_ids_byte_size / sizeof(CMIOObjectID);

#if DEBUG
    printf("Found %i CoreMediaIO devices on system\n", *device_count);
#endif
}

static inline bool
read_property(CMIOObjectID device_id, CMIOObjectPropertyAddress *property, void **value)
{
    if (!CMIOObjectHasProperty(device_id, property))
    {
        *value = nil;
        return false;
    }
    else
    {
        UInt32 byte_size = 0;
        CMIOObjectGetPropertyDataSize(device_id, property, 0, nil, &byte_size);

        void *data = malloc(byte_size);
        CMIOObjectGetPropertyData(device_id, property, 0, nil, byte_size, &byte_size, data);

        *value = data;
        return true;
    }
}

static inline bool read_magic_value(CMIOObjectID device_id)
{
    char *magic_value_buffer = nil;
    read_property(device_id, &kMagicProperty, (void **)&magic_value_buffer);

    bool match =
        magic_value_buffer != nil
            ? [kMagicValue isEqualToString:[NSString stringWithUTF8String:magic_value_buffer]]
            : false;

    free(magic_value_buffer);

    return match;
}

static inline bool read_uid(CMIOObjectID device_id, char **uid)
{
    return read_property(device_id, &kUIDProperty, (void **)uid);
}

static inline bool read_name(CMIOObjectID device_id, char **name)
{
    CFStringRef *ref = nil;
    read_property(device_id, &kDeviceNameProperty, (void **)&ref);

    if (ref == nil)
        return false;

    size_t length = CFStringGetLength(*ref) + 1;
    *name = malloc(length);
    CFStringGetCString(*ref, *name, length, kCFStringEncodingUTF8);

    CFRelease(*ref);
    return true;
}

static inline facade_error_code read_dimensions(facade_device *device)
{
    char *dimensions = nil;
    read_property(device->data->cmio_id, &kDimensionsProperty, (void **)&dimensions);

    NSScanner *scanner = [NSScanner scannerWithString:[NSString stringWithUTF8String:dimensions]];

    int temp_width = 0, temp_height = 0;
    [scanner scanInt:&temp_width];
    [scanner scanString:@"x" intoString:NULL];
    [scanner scanInt:&temp_height];

    if (device->width != temp_width || device->height != temp_height)
    {
        device->width = temp_width;
        device->height = temp_height;

        if (device->data->read_frame != nil)
        {
            free(device->data->read_frame);
            device->data->read_frame = nil;
        }
    }

    free(dimensions);

    return facade_error_none;
}

static inline facade_error_code read_frame_rate(facade_device *device)
{
    if (!CMIOObjectHasProperty(device->data->cmio_id, &kFrameRateProperty))
    {
        os_log_error(logger, "facade_device %s - Frame rate property not found.", device->uid);
        return facade_error_protocol;
    }

    UInt32 frame_rate_int_size = 0;
    CMIOObjectGetPropertyDataSize(
        device->data->cmio_id, &kFrameRateProperty, 0, nil, &frame_rate_int_size);

    if (frame_rate_int_size != sizeof(uint32_t))
    {
        os_log_error(logger,
                     "facade_device %s - Frame rate property has unexpected byte size.",
                     device->uid);

        return facade_error_protocol;
    }

    CMIOObjectGetPropertyData(device->data->cmio_id,
                              &kFrameRateProperty,
                              0,
                              nil,
                              frame_rate_int_size,
                              &frame_rate_int_size,
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
    CFTypeRef pixel_buffer_attribute_values[PIXEL_BUFFER_ATTRIBUTE_ENTRIES] = {
        CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &device->width),
        CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &device->height),
        CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &media_subtype),
        CFDictionaryCreate(kCFAllocatorDefault,
                           nil,
                           nil,
                           0,
                           &kCFCopyStringDictionaryKeyCallBacks,
                           &kCFTypeDictionaryValueCallBacks)};
    CFDictionaryRef pixel_buffer_attributes =
        CFDictionaryCreate(kCFAllocatorDefault,
                           (const void **)pixel_buffer_attribute_keys,
                           (const void **)pixel_buffer_attribute_values,
                           PIXEL_BUFFER_ATTRIBUTE_ENTRIES,
                           &kCFCopyStringDictionaryKeyCallBacks,
                           &kCFTypeDictionaryValueCallBacks);
    CVPixelBufferPoolCreate(
        kCFAllocatorDefault, nil, pixel_buffer_attributes, &device->data->write_buffer_pool);
    CFRelease(pixel_buffer_attributes);

#define BUFFER_AUX_ATTRIBUTE_ENTRIES 1
    CFStringRef aux_attribute_keys[BUFFER_AUX_ATTRIBUTE_ENTRIES] = {
        kCVPixelBufferPoolAllocationThresholdKey};
    CFTypeRef aux_attribute_values[BUFFER_AUX_ATTRIBUTE_ENTRIES] = {
        CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &kWriteBufferCapacity)};
    device->data->write_buffer_aux_attributes =
        CFDictionaryCreate(kCFAllocatorDefault,
                           (const void **)aux_attribute_keys,
                           (const void **)aux_attribute_values,
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

int on_device_changed(CMIOObjectID cmio_id,
                      UInt32 number_addresses,
                      const CMIOObjectPropertyAddress addresses[],
                      void *client_data)
{
    facade_device *device = (facade_device *)client_data;

    for (int i = 0; i < number_addresses; i++)
    {
        if (addresses[i].mElement == kCMIOObjectPropertyElementMain &&
            addresses[i].mScope == kCMIOObjectPropertyScopeGlobal)
        {
            if (addresses[i].mSelector == kDimensionsProperty.mSelector)
                read_dimensions(device);
            else if (addresses[i].mSelector == kFrameRateProperty.mSelector)
                read_frame_rate(device);
        }
    }

    if (device->data->changed_callback != nil)
        device->data->changed_callback(device->data->changed_context);

    return 0;
}

facade_device *read_device(CMIOObjectID device_id)
{
    facade_device *device = calloc(1, sizeof(facade_device));
    device->type = facade_device_type_video;
    device->data = calloc(1, sizeof(facade_device_data));
    device->data->cmio_id = device_id;
    device->data->write_sample_buffers =
        CFArrayCreateMutable(kCFAllocatorDefault, 6, &kCFTypeArrayCallBacks);

    UInt32 streamsArrayByteSize = 0;
    CMIOObjectGetPropertyDataSize(device_id, &kDeviceStreams, 0, nil, &streamsArrayByteSize);
    UInt32 streamCount = streamsArrayByteSize / sizeof(CMIOStreamID);

    if (streamCount != kIOStreamsPerDevice)
    {
        os_log_error(logger,
                     "facade_device @%s - Unexpected number of streams (%i vs %i)",
                     device->uid,
                     streamCount,
                     kIOStreamsPerDevice);

        free(device->data);
        free(device);

        return nil;
    }
    else
    {
        CMIOObjectGetPropertyData(device_id,
                                  &kDeviceStreams,
                                  0,
                                  nil,
                                  2 * sizeof(CMIOStreamID),
                                  &streamsArrayByteSize,
                                  &device->data->streams);
    }

    read_uid(device_id, (char **)&device->uid);
    read_name(device_id, (char **)&device->name);
    read_dimensions(device);
    read_frame_rate(device);
    read_format_description(device);

    device->data->changed_block =
        ^(UInt32 inClientDataSize, const CMIOObjectPropertyAddress *properties) {
            on_device_changed(device_id, inClientDataSize, properties, device);
        };
    CMIOObjectAddPropertyListenerBlock(
        device_id, &kDimensionsProperty, listener_queue, device->data->changed_block);
    CMIOObjectAddPropertyListenerBlock(
        device_id, &kFrameRateProperty, listener_queue, device->data->changed_block);

    return device;
}

void on_state_changed(void)
{
    if (state_changed_callback)
        state_changed_callback(state_changed_context);
}

facade_error_code facade_init(void)
{
    logger = os_log_create("gg.facade.Facade", "libfacade");

    CMIOObjectPropertyAddress plugInForBundleIDProperty = {kCMIOHardwarePropertyPlugInForBundleID,
                                                           kCMIOObjectPropertyScopeGlobal,
                                                           kCMIOHardwarePropertyPlugInForBundleID};

    UInt32 plugInIDByteSize = sizeof(kPlugInID);
    AudioValueTranslation translation = {
        .mInputData = &kPlugInBundleID,
        .mInputDataSize = sizeof(kPlugInBundleID),
        .mOutputData = &kPlugInID,
        .mOutputDataSize = sizeof(kPlugInID),
    };
    OSStatus result = CMIOObjectGetPropertyData(kCMIOObjectSystemObject,
                                                &plugInForBundleIDProperty,
                                                0,
                                                nil,
                                                sizeof(AudioValueTranslation),
                                                &plugInIDByteSize,
                                                &translation);

    listener_queue =
        dispatch_queue_create("gg.facade.Facade.libfacade", DISPATCH_QUEUE_SERIAL);
    state_changed_block = ^(UInt32 inClientDataSize, const CMIOObjectPropertyAddress *properties) {
        on_state_changed();
    };
    CMIOObjectAddPropertyListenerBlock(
        kPlugInID, &kStateProperty, listener_queue, state_changed_block);

    return result == kCMIOHardwareNoError && kPlugInID != kCMIOObjectUnknown
               ? facade_error_none
               : facade_error_not_installed;
}

@interface FacadeStateXMLImport : NSObject <NSXMLParserDelegate>

- (facade_state *)import;

@end

@implementation FacadeStateXMLImport

facade_state *state = nil;
facade_device_info *next_device = nil;
NSString *tag = nil;

- (instancetype)init
{
    state = nil;
    next_device = nil;
    tag = nil;
    return self;
}

- (facade_state *)import
{
    return state;
}

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    if (state == nil)
        state = calloc(1, sizeof(facade_state));
}

- (void)parser:(NSXMLParser *)parser
    didStartElement:(NSString *)elementName
       namespaceURI:(NSString *)namespaceURI
      qualifiedName:(NSString *)qName
         attributes:(NSDictionary<NSString *, NSString *> *)attributeDict
{

    tag = elementName;

    if ([elementName isEqualToString:@"video"])
    {
        if (next_device == nil)
            next_device = calloc(1, sizeof(facade_device_info));
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (tag != nil && [tag isEqualToString:@"apiVersion"])
    {
        char majorVersion = [string characterAtIndex:1] - '0';
        state->api_version = (facade_version)majorVersion;
    }
    else if (tag != nil && next_device != nil)
    {
        if ([tag isEqualToString:@"id"])
        {
            char *uid = calloc(1, [string length] + 1);
            next_device->uid = uid;
            strcpy(uid, [string UTF8String]);
        }
        else if ([tag isEqualToString:@"name"])
        {
            char *name = calloc(1, [string length] + 1);
            next_device->name = name;
            strcpy(name, [string UTF8String]);
        }
        else if ([tag isEqualToString:@"width"])
        {
            next_device->width = [string intValue];
        }
        else if ([tag isEqualToString:@"height"])
        {
            next_device->height = [string intValue];
        }
        else if ([tag isEqualToString:@"frameRate"])
        {
            next_device->frame_rate = [string intValue];
        }
    }
}

- (void)parser:(NSXMLParser *)parser
    didEndElement:(NSString *)elementName
     namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qName
{
    tag = nil;

    if ([elementName isEqualToString:@"video"] && next_device != nil && state != nil)
    {
        next_device->type = facade_device_type_video;

        if (state->devices == nil)
        {
            state->devices = next_device;
            next_device->next = next_device;
        }
        else
        {
            next_device->next = state->devices->next;
            state->devices->next = next_device;
        }

        next_device = nil;
    }
}

@end

facade_error_code facade_read_state(facade_state **state)
{
    if (kPlugInID == 0)
        return facade_error_not_initialized;

    OSStatus result = kCMIOHardwareNoError;

    UInt32 stateValueByteSize = 0;
    result = CMIOObjectGetPropertyDataSize(kPlugInID, &kStateProperty, 0, nil, &stateValueByteSize);
    char *stateValue = calloc(stateValueByteSize, sizeof(char));
    result = CMIOObjectGetPropertyData(
        kPlugInID, &kStateProperty, 0, nil, stateValueByteSize, &stateValueByteSize, stateValue);

    FacadeStateXMLImport *importer = [[FacadeStateXMLImport alloc] init];

    @autoreleasepool
    {
        NSXMLParser *parser = [[NSXMLParser alloc]
            initWithData:[NSData dataWithBytes:stateValue length:stateValueByteSize]];
        parser.delegate = importer;
        [parser parse];
    }

    *state = importer.import;

    return result == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}

facade_error_code facade_write_state(facade_state *state)
{
    OSStatus result = kCMIOHardwareNoError;

    @autoreleasepool
    {
        NSXMLElement *facade = [NSXMLElement elementWithName:@"facade"];
        NSXMLElement *apiVersion = [NSXMLElement elementWithName:@"apiVersion" stringValue:@"v1"];
        NSXMLElement *devices = [NSXMLElement elementWithName:@"devices"];

        [facade addChild:apiVersion];
        [facade addChild:devices];

        facade_device_info *device_info = state->devices;

        if (device_info != nil)
        {
            do
            {
                NSXMLElement *device = [NSXMLElement elementWithName:@"video"];
                NSXMLElement *_id =
                    device_info->uid
                        ? [NSXMLElement
                              elementWithName:@"id"
                                  stringValue:[NSString stringWithUTF8String:device_info->uid]]
                        : nil;
                NSXMLElement *name = [NSXMLElement
                    elementWithName:@"name"
                        stringValue:[NSString stringWithUTF8String:device_info->name]];
                NSXMLElement *width = [NSXMLElement
                    elementWithName:@"width"
                        stringValue:[NSString stringWithFormat:@"%u", device_info->width]];
                NSXMLElement *height = [NSXMLElement
                    elementWithName:@"height"
                        stringValue:[NSString stringWithFormat:@"%u", device_info->height]];
                NSXMLElement *frame_rate = [NSXMLElement
                    elementWithName:@"frameRate"
                        stringValue:[NSString stringWithFormat:@"%u", device_info->frame_rate]];

                if (_id != nil)
                    [device addChild:_id];
                [device addChild:name];
                [device addChild:width];
                [device addChild:height];
                [device addChild:frame_rate];

                [devices addChild:device];

                device_info = device_info->next;
            }
            while (device_info != nil && device_info != state->devices);
        }

        NSXMLDocument *document = [[NSXMLDocument alloc] initWithRootElement:facade];
        [document setVersion:@"1.0"];
        [document setCharacterEncoding:@"UTF-8"];

        NSData *xmlData = [document XMLDataWithOptions:NSXMLNodePrettyPrint];
        NSString *xmlString = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];

        result = CMIOObjectSetPropertyData(kPlugInID,
                                           &kStateProperty,
                                           0,
                                           nil,
                                           (UInt32)[xmlString length] + 1,
                                           xmlString.UTF8String);
    }

    if (result != kCMIOHardwareNoError)
        os_log_error(logger, "Failed to write state (OSStatus %i)", result);

    return result == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}

facade_error_code facade_on_state_changed(facade_callback callback, void *context)
{
    state_changed_callback = callback;
    state_changed_context = context;

    return facade_error_none;
}

facade_error_code facade_dispose_state(facade_state **state)
{
    facade_device_info *device_info = (*state)->devices;

    if (device_info != nil)
    {
        do
        {
            facade_device_info *next = device_info->next;
            dispose_device_info(&device_info);
            device_info = next;
        }
        while (device_info != (*state)->devices);
    }

    free(*state);
    *state = nil;

    return facade_error_none;
}

facade_error_code facade_list_devices(facade_device **list)
{
    CMIOObjectID *device_ids = nil;
    UInt32 device_count = 0;
    list_devices(&device_ids, &device_count);

    for (UInt32 i = 0; i < device_count; i++)
    {
        if (read_magic_value(device_ids[i]))
        {
            facade_device *device = read_device(device_ids[i]);

            if (device != nil)
                insert_device(list, device);
        }
    }

    free(device_ids);

    return facade_error_none;
}

facade_error_code facade_find_device_by_uid(const char *uid, facade_device **device)
{
    CMIOObjectID *device_ids = nil;
    UInt32 device_count = 0;
    list_devices(&device_ids, &device_count);

    *device = nil;

    for (UInt32 i = 0; i < device_count && *device == nil; i++)
    {
        if (!read_magic_value(device_ids[i]))
            continue;

        char *device_uid = nil;
        read_uid(device_ids[i], &device_uid);

        int match = strcmp(device_uid, uid) == 0;

        free(device_uid);

        if (match)
            *device = read_device(device_ids[i]);
    }

    free(device_ids);

    return *device != nil ? facade_error_none : facade_error_not_found;
}

facade_error_code facade_find_device_by_name(const char *name, facade_device **device)
{
    CMIOObjectID *device_ids = nil;
    UInt32 device_count = 0;
    list_devices(&device_ids, &device_count);

    *device = nil;

    for (UInt32 i = 0; i < device_count && *device == nil; i++)
    {
        if (!read_magic_value(device_ids[i]))
            continue;

        char *device_name = nil;
        read_name(device_ids[i], &device_name);

        int match = strcmp(device_name, name) == 0;

        free(device_name);

        if (match)
            *device = read_device(device_ids[i]);
    }

    free(device_ids);

    return *device != nil ? facade_error_none : facade_error_not_found;
}

facade_error_code facade_dispose_device(facade_device **device_ref)
{
    facade_device *device = *device_ref;

    release_write_buffer_pool(device);

    CMIOObjectRemovePropertyListenerBlock(
        device->data->cmio_id, &kDimensionsProperty, listener_queue, device->data->changed_block);
    CMIOObjectRemovePropertyListenerBlock(
        device->data->cmio_id, &kFrameRateProperty, listener_queue, device->data->changed_block);

    free(device->data->read_frame);
    device->data->read_frame = nil;

    if (device->data->read_queue != nil)
    {
        CFRelease(device->data->read_queue);
        device->data->read_queue = nil;
    }

    if (device->data->write_queue != nil)
    {
        CFRelease(device->data->write_queue);
        device->data->write_queue = nil;
    }

    if (device->data->format_description != nil)
    {
        CFRelease(device->data->format_description);
        device->data->format_description = nil;
    }

    free(device->data);
    device->data = nil;

    free((void *)device->uid);
    device->uid = nil;

    free((void *)device->name);
    device->name = nil;

    free(device);
    *device_ref = nil;

    return facade_error_none;
}

facade_error_code facade_create_device(facade_device_info *options)
{
    if (options->type != facade_device_type_video || options->uid != nil || options->name == nil ||
        options->width > 8192 || options->height > 8192 || options->frame_rate < 10 ||
        options->frame_rate > 120)
        return facade_error_invalid_input;

    facade_state *state = nil;
    facade_error_code read_error = facade_read_state(&state);
    if (read_error != facade_error_none)
        return read_error;

    facade_device_info *copy = malloc(sizeof(facade_device_info));
    memcpy(copy, options, sizeof(facade_device_info));
    copy->uid = nil;
    copy->name = malloc(strlen(options->name) + 1);
    strcpy((char *)copy->name, options->name);

    insert_device_info(&state->devices, copy);
    facade_error_code write_error = facade_write_state(state);

    facade_dispose_state(&state);

    return write_error;
}

facade_error_code facade_edit_device(char const *uid, facade_device_info *options)
{
    if (options->name != nil)
        return facade_error_invalid_input;

    facade_state *state = nil;
    facade_error_code read_error = facade_read_state(&state);
    if (read_error != facade_error_none)
        return read_error;

    facade_error_code error = facade_error_none;
    facade_device_info *target_device = nil;

    if (state->devices != nil)
    {
        facade_device_info *info = state->devices;

        do
        {
            printf("%s vs %s\n", info->uid, uid);
            if (strcmp(info->uid, uid) == 0)
                target_device = info;

            info = info->next;
        }
        while (info != state->devices && target_device == nil);
    }

    if (target_device == nil)
    {
        error = facade_error_not_found;
    }
    else if (target_device->type != options->type)
    {
        error = facade_error_invalid_type;
    }
    else
    {
        if (options->width != 0)
            target_device->width = options->width;
        if (options->height != 0)
            target_device->height = options->height;
        if (options->frame_rate != 0)
            target_device->frame_rate = options->frame_rate;

        error = facade_write_state(state);
    }

    facade_dispose_state(&state);

    return error;
}

facade_error_code facade_delete_device(char const *uid)
{
    facade_state *state = nil;
    facade_error_code read_error = facade_read_state(&state);
    if (read_error != facade_error_none)
        return read_error;

    bool found = false;

    if (state->devices != nil)
    {
        facade_device_info *last = state->devices;
        facade_device_info *info = last->next;

        do
        {
            if (strcmp(info->uid, uid) == 0)
            {
                last->next = info->next;

                if (last == info)
                {
                    state->devices = nil;
                    last = nil;
                }
                else if (info == state->devices)
                {
                    state->devices = last;
                }

                dispose_device_info(&info);
                found = true;
                
                if (last != nil)
                    info = last->next;
            }
            else
            {
                last = info;
                info = info->next;
            }
        }
        while (info != nil && info != state->devices->next);
    }

    if (!found)
        return facade_error_not_found;

    facade_error_code write_error = facade_write_state(state);
    facade_dispose_state(&state);

    return write_error;
}

facade_error_code
facade_on_device_changed(facade_device *device, facade_callback callback, void *context)
{
    device->data->changed_callback = callback;
    device->data->changed_context = context;

    return facade_error_none;
}

void on_read_queue_ready(CMIOStreamID _, void *__, void *device)
{
    facade_device_data *data = ((facade_device *)device)->data;
    if (data->read_callback != nil)
        (*data->read_callback)(data->read_context);
}

facade_error_code facade_read_open(facade_device *device)
{
    if (device->data->read_queue != nil)
    {
        os_log_error(logger, "facade_read_open %s - Input stream is already open.", device->uid);
        return facade_error_invalid_state;
    }

    device->data->read_callback = nil;
    device->data->read_context = nil;

    OSStatus status = CMIODeviceStartStream(device->data->cmio_id, device->data->streams[0]);

    if (status != kCMIOHardwareNoError)
    {
        os_log_error(logger, "facade_read_open %s - Input stream failed to open.", device->uid);
        return facade_error_unknown;
    }

    status = CMIOStreamCopyBufferQueue(
        device->data->streams[0], &on_read_queue_ready, device, &device->data->read_queue);

    if (status != kCMIOHardwareNoError)
    {
        os_log_error(
            logger, "facade_read_open %s - Input buffer queue could not be copied", device->uid);
        return facade_error_unknown;
    }

    return facade_error_none;
}

facade_error_code
facade_read_callback(facade_device *device, facade_callback callback, void *context)
{
    device->data->read_callback = callback;
    device->data->read_context = context;

    return facade_error_none;
}

facade_error_code facade_read_frame(facade_device *device, void **buffer, size_t *buffer_size)
{
    if (device->data->read_queue == nil)
        return facade_error_reader_not_ready;

    OSStatus status = kCMIOHardwareNoError;

    CMSampleBufferRef sample_buffer =
        (CMSampleBufferRef)CMSimpleQueueDequeue(device->data->read_queue);

    if (sample_buffer == nil)
    {
#if DEBUG
        os_log_error(
            logger, "facade_read_frame %s - Input stream has no frames left.", device->uid);
#endif
        return facade_error_reader_not_ready;
    }

    CVImageBufferRef image_buffer = CMSampleBufferGetImageBuffer(sample_buffer);
    CVPixelBufferLockBaseAddress(image_buffer, 0);

    char *data = CVPixelBufferGetBaseAddress(image_buffer);
    size_t data_length = CVPixelBufferGetDataSize(image_buffer);

    if (data_length < device->width * device->height * BYTES_PER_PIXEL)
    {
        os_log_error(logger,
                     "facade_read_frame %s - Receive buffer has wrong size (%li). (OSStatus %i)",
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
    OSStatus status = CMIODeviceStopStream(device->data->cmio_id, device->data->streams[0]);

    if (device->data->read_queue != nil)
    {
        CFRelease(device->data->read_queue);
        device->data->read_queue = nil;
    }

    return status == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}

void on_write_queue_ready(CMIOStreamID _, void *__, void *device)
{
    facade_device_data *data = ((facade_device *)device)->data;

    if (data->write_callback != nil)
        (*data->write_callback)(data->write_context);
}

facade_error_code facade_write_open(facade_device *device)
{
    if (device->data->write_queue != nil)
    {
        os_log_error(logger, "facade_write_open %s - Output stream is already open.", device->uid);
        return facade_error_invalid_state;
    }

    OSStatus status = CMIODeviceStartStream(device->data->cmio_id, device->data->streams[1]);

    if (status != kCMIOHardwareNoError)
    {
        os_log_error(logger, "facade_write_open %s - Output stream failed to open.", device->uid);
        return facade_error_unknown;
    }

    status = CMIOStreamCopyBufferQueue(
        device->data->streams[1], &on_write_queue_ready, device, &device->data->write_queue);

    if (status != kCMIOHardwareNoError)
    {
        os_log_error(
            logger, "facade_write_open %s - Output buffer queue could not be copied.", device->uid);
        return facade_error_unknown;
    }

    return facade_error_none;
}

facade_error_code
facade_write_callback(facade_device *device, facade_callback callback, void *context)
{
    device->data->write_callback = callback;
    device->data->write_context = context;

    return facade_error_none;
}

facade_error_code facade_write_frame(facade_device *device, void *buffer, size_t buffer_size)
{
    if (device->data->write_queue == nil)
    {
        os_log_error(logger, "facade_write_frame %s - Output stream was not opened.", device->uid);
        return facade_error_writer_not_ready;
    }
    if (buffer_size < BYTES_PER_PIXEL * device->width * device->height)
    {
        os_log_error(logger,
                     "facade_write_frame %s - Send buffer has wrong size. (%li vs %li)",
                     device->uid,
                     buffer_size,
                     (size_t)BYTES_PER_PIXEL * device->width * device->height);
        return facade_error_invalid_input;
    }
    if (device->data->write_buffer_pool == nil)
    {
#if DEBUG
        os_log_debug(logger, "facade_write_frame %s - Allocating write buffer pool", device->uid);
#endif
        create_write_buffer_pool(device);
    }

    OSStatus status = kCMIOHardwareNoError;

    CMSampleTimingInfo timingInfo = {};
    timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock());
    CMSampleBufferRef sample_buffer;
    CVPixelBufferRef pixel_buffer;
    CVReturn success = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
        kCFAllocatorDefault,
        device->data->write_buffer_pool,
        device->data->write_buffer_aux_attributes,
        &pixel_buffer);
    if (success != kCVReturnSuccess)
    {
        os_log_error(logger,
                     "facade_write_frame %s - Failed to allocate pixel buffer. (OSStatus %i)",
                     device->uid,
                     success);
        return facade_error_unknown;
    }

    CVPixelBufferLockBaseAddress(pixel_buffer, 0);
    memcpy(CVPixelBufferGetBaseAddress(pixel_buffer),
           buffer,
           (size_t)BYTES_PER_PIXEL * device->width * device->height);
    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);

    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                                pixel_buffer,
                                                true,
                                                nil,
                                                nil,
                                                device->data->format_description,
                                                &timingInfo,
                                                &sample_buffer);
    if (status != kCMBlockBufferNoErr)
    {
        os_log_error(logger,
                     "facade_write_frame %s - Failed to create sample buffer. (OSStatus %i)",
                     device->uid,
                     status);
        CFRelease(sample_buffer);
        CVPixelBufferRelease(pixel_buffer);

        return facade_error_unknown;
    }

    status = CMSimpleQueueEnqueue(device->data->write_queue, sample_buffer);

    if (status != kCMBlockBufferNoErr)
    {
        os_log_error(logger,
                     "facade_write_frame %s - Failed to queue frame. (OSStatus %i)",
                     device->uid,
                     status);
    }

    CVPixelBufferRelease(pixel_buffer);

    return status == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}

facade_error_code facade_write_close(facade_device *device)
{
    OSStatus status = CMIODeviceStopStream(device->data->cmio_id, device->data->streams[1]);

    if (device->data->write_queue != nil)
    {
        CFRelease(device->data->write_queue);
        device->data->write_queue = nil;
    }

    return status == kCMIOHardwareNoError ? facade_error_none : facade_error_unknown;
}
