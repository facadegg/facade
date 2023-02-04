//
//  FacadeKit.hpp
//  FacadeKit
//
//  Created by Shukant Pal on 1/29/23.
//

#ifndef FacadeKit_D557512F84D244B7B3830C04E09468AD
#define FacadeKit_D557512F84D244B7B3830C04E09468AD

#include <ctype.h>

typedef enum {
    video_facade = 0,
} facade_type;

typedef enum {
    facade_error_none = 0,
    facade_error_unknown = 1,
    facade_error_invalid_type = 2
} facade_error_code;

typedef uint64_t facade_id;

typedef struct facade_device_data facade_device_data;
typedef struct facade_device facade_device;
typedef struct facade_device {
    facade_device *next;
    facade_type type;
    uint64_t uid;
    float frame_rate;
    facade_device_data *data;
} facade_device;

typedef void (*facade_write_callback)(void *context);

void facade_init(void);
void facade_list_devices(facade_device **list);
facade_error_code facade_read(facade_device *, void **buf, size_t *buf_size);
facade_error_code facade_write(facade_device *, void *buf, facade_write_callback callback, void *context);

#endif /* FacadeKit_D557512F84D244B7B3830C04E09468AD */
