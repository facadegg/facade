from cffi import FFI
import os
import sys

LIBFACADE_LIB_DIR = os.getenv("LIBFACADE_DIR")

if sys.platform == 'darwin':
    if LIBFACADE_LIB_DIR is None:
        LIBFACADE_LIB_DIR = '/Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework/'

os.environ['DYLD_LIBRARY_PATH'] = f"{LIBFACADE_LIB_DIR}" \
                                  f"{':' +  os.environ['DYLD_LIBRARY_PATH'] if 'DYLD_LIBRARY_PATH' in os.environ else ''}"

ffi = FFI()

ffi.cdef(
    """
    typedef enum {
        video_facade = 0
    } facade_type;

    typedef enum {
        facade_error_none = 0
    } facade_error_code;
    
    typedef uint64_t facade_id;
    
    typedef struct facade_device_data facade_device_data;
    typedef struct facade_device facade_device;
    typedef struct facade_device {
        facade_device *next;
        facade_type type;
        facade_id uid;
        uint32_t width;
        uint32_t height;
        uint32_t frame_rate;
    } facade_device;

    typedef void (*facade_read_callback)(void *context);
    typedef void (*facade_write_callback)(void *context);
    
    void facade_init(void);
    void facade_list_devices(facade_device **list);
    facade_error_code facade_init_device(facade_id, facade_device *);
    facade_error_code facade_dispose_device(facade_device *);
    
    facade_error_code facade_read(facade_device *, void **buffer, size_t *buffer_size);
    facade_error_code facade_reader(facade_device *, facade_read_callback callback, void *context);
    facade_error_code facade_write(facade_device *, void *buf, size_t buffer_size);
    facade_error_code facade_writer(facade_device *, facade_write_callback callback, void *context);
    """
)

libfacade = ffi.dlopen('facade')
