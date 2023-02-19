//
//  facade.h
//  libfacade
//
//  Created by Shukant Pal on 1/29/23.
//

#ifndef FACADE_H_D557512F84D244B7B3830C04E09468AD
#define FACADE_H_D557512F84D244B7B3830C04E09468AD

#include <ctype.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * @file
 *
 * @brief Declares the public, cross-platform APIs exposed by libfacade implementations.
 *
 * @author Shukant Pal, while building Paal Maxima
 */

/**
 * @def BYTES_PER_PIXEL
 * The size of each pixel when reading video frames.
 */
#define BYTES_PER_PIXEL 4

/**
 * @defgroup Data structures
 * @{
 */

/**
 * @enum facade_device_type
 * @brief An enumeration of the different types of facade devices.
 */
typedef enum {
    facade_device_type_video = 0,       /*!< A video device (camera). */
} facade_device_type;

/**
 * @enum facade_error_code
 * @brief An enumeration of all error codes used in libfacade.
 */
typedef enum {
    facade_error_none = 0,             /*!< Success */
    facade_error_unknown = 1,          /*!< An unspecified error that is system specific */
    facade_error_protocol = 2,         /*!< An incompatibility between libfacade and Facade system extensions */
    facade_error_invalid_type = 3,     /*!< A device with the wrong type was passed */
    facade_error_invalid_state = 4,    /*!< A given operation cannot be done without another prerequisite */
    facade_error_invalid_input = 5,    /*!< The passed argument have unacceptable values */
    facade_error_reader_not_ready = 6, /*!< The device is not ready to be read again */
    facade_error_writer_not_ready = 7, /*!< The device is not ready to be written to again */
    facade_error_not_installed = 8,    /*!< The system extensions required for Facade are not installed */
    facade_error_not_initialized = 9,  /*!< libfacade has not been initialized (see facade_init()) */
    facade_error_not_found = 10,       /*!< The device required was not found */
} facade_error_code;

/**
 * @typedef facade_version
 * @brief An opaque handle to the version of Facade installed on the system
 */
typedef uint64_t facade_version;

typedef struct facade_device_info facade_device_info;

/**
 * @brief Data representing the configuration of a device
 */
typedef struct facade_device_info {
    facade_device_info *next;          /*!< The next item in a circular singly-linked list. */
    facade_device_type type;           /*!< The type of device */
    const char *uid;                   /*!< An identifier for this device that is unique on this system.  */
    const char *name;                  /*!< The name assigned to this device on creation */
    uint32_t width;                    /*!< The width, in pixels, of the video frames in this device */
    uint32_t height;                   /*!< The height, in pixels, of the video frames in this device */
    uint32_t frame_rate;               /*!< The rate at which video frames are produced by this device */
} facade_device_info;

/**
 * @brief The state of all devices virtualized by Facade
 */
typedef struct {
    facade_version api_version;/*!< An opaque handle to the version of the Facade system software. */
    facade_device_info *devices;/*!< A singly linked list of all devices virtualized by Facade. */
} facade_state;

typedef struct facade_device_data facade_device_data;
typedef struct facade_device facade_device;

/**
 * @brief An open Facade device
 */
typedef struct facade_device {
    facade_device *next;               /*!< The next item in a circular singly-linked list. */
    facade_device_type type;           /*!< The type of device */
    const char *uid;                   /*!< An identifier for this device that is unique on this system. */
    char const *name;                  /*!< The name assigned to this device on creation */
    uint32_t width;                    /*!< The width, in pixels, of the video frames in this device */
    uint32_t height;                   /*!< The height, in pixels, of the video frames in this device */
    uint32_t frame_rate;               /*!< The rate at which video frames are produced by this device */
    facade_device_data *data;          /*!< Platform-specific handles used by Facade to implement IO operations. */
} facade_device;

/**
 * @brief A callback that can be registered when read / write operations are ready on a device.
 */
typedef void (*facade_callback)(void *context);

/**
 * @}
 *
 * @defgroup libfacade
 * @{
 */

/**
 * @brief Initialize the Facade library.
 * @return \c facade_error_none on success.
 * @return \c facade_error_not_installed if Facade system extensions are not installed or are not reachable.
 *
 * This must be called at application initialization. If libfacade is used without calling \c facade_init,
 * it will result in undefined behavior.
 */
facade_error_code facade_init(void);

/**
 * @}
 *
 * @defgroup Direct state access
 * @{
 */

/**
 * @brief Read Facade system extension state.
 * @param[out] p - The pointer that will store the output.
 * @return \c facade_error_none on success.
 * @return \c facade_error_not_initialized if facade_init() was not called.
 * @return \c facade_error_unknown if the state could not be read.
 *
 * This uses IPC to request a copy of system extension state. It is recommended to keep a copy
 * if it will be frequently read.
 */
facade_error_code facade_read_state(facade_state **p);

/**
 * @brief Write Facade system extension state.
 * @param[out] p - The state to be written.
 * @return \c facade_error_none on success.
 * @return \c facade_error_unknown if the state could not be written.
 *
 * Be careful when using this directly, as it will overwrite all existing state. This means any virtual
 * devices that were not omitted in the state will be deleted. It is recommended to use
 * facade_create_device(), facade_edit_device(), facade_delete_device() when possible.
 *
 * Note that the new state will not be immediately reflected. You may need to poll facade_read_state().
 */
facade_error_code facade_write_state(facade_state *p);

/**
 * @brief Listen for changes to global Facade state. This will replace any existing listener.
 * @param callback - To be called when any state changes.
 * @param context - The (only) argument passed to \p callback.
 * @return \c facade_error_none on success.
 */
facade_error_code facade_on_state_changed(facade_callback callback, void *context);

/**
 * @brief Dispose a copy of state data.
 * @param[in, out] p - The pointer holding the state data.
 * @return \c facade_error_none on success.
 */
facade_error_code facade_dispose_state(facade_state **p);


/**
 * @}
 *
 * @defgroup Device discovery
 * @{
 */

/**
 * @brief List all devices available for I/O.
 * @param[out] p - A singly-linked list of devices. This may be \c NULL if the list is empty!
 * @return \c facade_error_none on success.
 *
 * This may not include all devices returned by facade_read_state() because it uses the the standard
 * system APIs for discovering devices used by other applications.
 */
facade_error_code facade_list_devices(facade_device **p);

/**
 * @brief Find a device by it's UID.
 * @param[in] uid - The UID the device to find, by exact match.
 * @param[out] p - The device found.
 * @return \c facade_error_none on success.
 * @return \c facade_error_not_found if such a device was not found.
 */
facade_error_code facade_find_device_by_uid(char const *uid, facade_device **p);

/**
 * @brief Find a device by its name.
 * @param[in] name - The name of the device to find, by exact match.
 * @param[out] p - The device found.
 * @return \c facade_error_none on success.
 * @return \c facade_error_not_found if such a device was not found.
 */
facade_error_code facade_find_device_by_name(char const *name, facade_device **p);

/**
 * @brief Dispose a \c facade_device object.
 * @param[in, out] p - The device to be disposed. This must not be \c NULL.
 * @return \c facade_error_none on success.
 */
facade_error_code facade_dispose_device(facade_device **p);

/**
 * @brief Create a device with the provided parameters.
 * @param[in] options - The configuration for the new device.
 * @return \c facade_error_none on success.
 * @return \c facade_error_invalid_input if the device type is not a valid \c facade_device_type.
 * @return \c facade_error_invalid_input if the device UID is set (it must be \c NULL).
 * @return \c facade_error_invalid_input if the device name is not set (it must \b not be \c NULL).
 * @return \c facade_error_invalid_input if specifying a width greater than 8192px for a video device.
 * @return \c facade_error_invalid_input if specifying a height greater than 8192px for a video device.
 * @return \c facade_error_invalid_input if specifying a frame rate less than 10 or greater than 120 for a video device.
 * @return \c facade_error_unknown if there is an error reading or writing state.
 */
facade_error_code facade_create_device(facade_device_info *options);

/**
 * @brief Edit a device given the new options.
 * @param[in] uid - The UID string of the device to edit.
 * @param[in] options - The modified parameters. Any fields set to \c NULL or \c 0 will be ignored.
 * @return \c facade_error_none on success.
 * @return \c facade_error_not_found if the device doesn't exist.
 * @return \c facade_error_invalid_type if the device type does not match.
 * @return \c facade_error_unknown if there is an error reading or writing state.
 */
facade_error_code facade_edit_device(char const *uid, facade_device_info *options);

/**
 * @brief Delete a device by its UID.
 * @param[in] uid - The UID string of the device to delete.
 * @return \c facade_error_none on success.
 * @return \c facade_error_not_found if the device doesn't exist.
 * @return \c facade_error_unknown if there is an error reading or writing state.
 */
facade_error_code facade_delete_device(char const *uid);

/**
 * @brief Listen for changes to device configuration
 * @return \c facade_error_none on success.
 *
 * \c facade_device will auto-update automatically on device configuration changes. This function merely
 * registers the callback to also be called.
 */
facade_error_code facade_on_device_changed(facade_device *, facade_callback callback, void *context);

/**
 * @}
 *
 * @defgroup I/O
 * @{
 */

/**
 * @brief Open a device for reads.
 * @param[in] p - The device to open.
 * @return \c facade_error_none on success.
 * @return \c facade_error_invalid_state if the device is already open for reads.
 * @return \c facade_error_unknown if there was an error opening the device's output stream.
 *
 * Note that you can open a device for reads and writes simultaneously.
 */
facade_error_code facade_read_open(facade_device *p);

/**
 * @brief Register a callback for when the device is ready to be read again.
 * @param[in] p - The device.
 * @param[in] callback - To be called when the device's output stream has pushed.
 * @param[in] context - The (only) argument to pass to \p callback.
 * @return \c facade_error_none on success.
 */
facade_error_code facade_read_callback(facade_device *p, facade_callback callback, void *context);

/**
 * @brief Read a frame from the video device.
 * @param[in] p - The video device.
 * @param[out] buffer - The BGRA32 pixel buffer holding the data. This may be overwritten on future reads.
 * @param[out] buffer_size - The size of the pixel buffer.
 * @return \c facade_error_none on success.
 * @return \c facade_error_reader_not_ready if the device's output stream is empty.
 * @return \c facade_error_unknown if there was another issue reading the output stream.
 */
facade_error_code facade_read_frame(facade_device *p, void **buffer, size_t *buffer_size);

/**
 * @brief Close the device for reads.
 * @param[in] p - The device to close.
 * @return \c facade_error_none on success.
 * @return \c facade_error_unknown if there was another issue closing the device's output stream.
 */
facade_error_code facade_read_close(facade_device *p);

/**
 * @brief Open a device for writes.
 * @copydoc facade_read_open
 */
facade_error_code facade_write_open(facade_device *);

/**
 * @brief Register a callback for when the device is ready to be written again.
 * @param[in] p - The device.
 * @param[in] callback - To be called when the device's input stream has pulled.
 * @param[in] context - The (only) argument to pass to \p callback.
 * @return \c facade_error_none on success.
 */
facade_error_code facade_write_callback(facade_device *p, facade_callback callback, void *context);

/**
 * @brief Write a frame from the video device.
 * @param[in] p - The video device.
 * @param[in] buffer - The BGRA32 pixel buffer holding the data.
 * @param[in] buffer_size - The size of the pixel buffer.
 * @return \c facade_error_none on success.
 * @return \c facade_error_invalid_input if the pixel buffer size is not the correct byte size (4 * width * height)
 * @return \c facade_error_writer_not_ready if the device's input stream is at full capacity.
 * @return \c facade_error_unknown if there was another issue writing to the input stream.
 */
facade_error_code facade_write_frame(facade_device *p, void *buffer, size_t buffer_size);

/**
 * @brief Close the device for writes.
 * @param[in] p - The device to close.
 * @return \c facade_error_none on success.
 * @return \c facade_error_unknown if there was another issue closing the device's input stream.
 */
facade_error_code facade_write_close(facade_device *p);

/**
 * @}
 */

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* FACADE_H_D557512F84D244B7B3830C04E09468AD */
