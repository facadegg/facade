facade_h = """
typedef enum {
    facade_device_type_video = 0,       
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
    facade_error_not_installed = 8,    
    facade_error_not_initialized = 9,  
    facade_error_not_found = 10,       
} facade_error_code;
typedef uint64_t facade_version;
typedef struct facade_device_info facade_device_info;
typedef struct facade_device_info {
    facade_device_info *next;          
    facade_device_type type;           
    const char *uid;                   
    const char *name;                  
    uint32_t width;                    
    uint32_t height;                   
    uint32_t frame_rate;               
} facade_device_info;
typedef struct {
    facade_version api_version;
    facade_device_info *devices;
} facade_state;
typedef struct facade_device_data facade_device_data;
typedef struct facade_device facade_device;
typedef struct facade_device {
    facade_device *next;               
    facade_device_type type;           
    const char *uid;                   
    char const *name;                  
    uint32_t width;                    
    uint32_t height;                   
    uint32_t frame_rate;               
    facade_device_data *data;          
} facade_device;
typedef void (*facade_callback)(void *context);
facade_error_code facade_init(void);
facade_error_code facade_read_state(facade_state **p);
facade_error_code facade_write_state(facade_state *p);
facade_error_code facade_on_state_changed(facade_callback callback, void *context);
facade_error_code facade_dispose_state(facade_state **p);
facade_error_code facade_list_devices(facade_device **p);
facade_error_code facade_find_device_by_uid(char const *uid, facade_device **p);
facade_error_code facade_find_device_by_name(char const *name, facade_device **p);
facade_error_code facade_dispose_device(facade_device **p);
facade_error_code facade_create_device(facade_device_info *options);
facade_error_code facade_edit_device(char const *uid, facade_device_info *options);
facade_error_code facade_delete_device(char const *uid);
facade_error_code facade_on_device_changed(facade_device *, facade_callback callback, void *context);
facade_error_code facade_read_open(facade_device *p);
facade_error_code facade_read_callback(facade_device *p, facade_callback callback, void *context);
facade_error_code facade_read_frame(facade_device *p, void **buffer, size_t *buffer_size);
facade_error_code facade_read_close(facade_device *p);
facade_error_code facade_write_open(facade_device *);
facade_error_code facade_write_callback(facade_device *p, facade_callback callback, void *context);
facade_error_code facade_write_frame(facade_device *p, void *buffer, size_t buffer_size);
facade_error_code facade_write_close(facade_device *p);
void free(void *);
"""
