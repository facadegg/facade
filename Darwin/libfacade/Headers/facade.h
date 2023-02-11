//
//  FacadeKit.hpp
//  FacadeKit
//
//  Created by Shukant Pal on 1/29/23.
//

#ifndef FacadeKit_D557512F84D244B7B3830C04E09468AD
#define FacadeKit_D557512F84D244B7B3830C04E09468AD

#include <ctype.h>

#define BYTES_PER_PIXEL 4

typedef enum {
    facade_type_video = 0,
} facade_device_type;

typedef enum {
    facade_error_none = 0,
    facade_error_unknown = 1,
    facade_error_protocol = 2,
    facade_error_invalid_type = 3,
    facade_error_invalid_state = 4,
    facade_error_invalid_input = 5,
    facade_error_reader_not_ready = 6,
    facade_error_writer_not_ready = 7,
} facade_error_code;

typedef uint64_t facade_id;

typedef struct facade_device_data facade_device_data;
typedef struct facade_device facade_device;
typedef struct facade_device {
    facade_device *next;
    facade_device_type type;
    facade_id uid;
    uint32_t width;
    uint32_t height;
    uint32_t frame_rate;
    facade_device_data *data;
} facade_device;

typedef void (*facade_callback)(void *context);

void facade_init(void);
void facade_list_devices(facade_device **list);

facade_error_code facade_init_device(facade_id, facade_device *);
facade_error_code facade_dispose_device(facade_device *);
facade_error_code facade_create_device(facade_device *options);

facade_error_code facade_read_open(facade_device *);
facade_error_code facade_read_callback(facade_device *, facade_callback callback, void *context);
facade_error_code facade_read_frame(facade_device *, void **buffer, size_t *buffer_size);
facade_error_code facade_read_close(facade_device *);

facade_error_code facade_write_open(facade_device *);
facade_error_code facade_write_callback(facade_device *, facade_callback callback, void *context);
facade_error_code facade_write_frame(facade_device *, void *buf, size_t buffer_size);
facade_error_code facade_write_close(facade_device *);

#endif /* FacadeKit_D557512F84D244B7B3830C04E09468AD */
