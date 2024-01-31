from abc import ABCMeta, abstractmethod
from typing import Union, Literal, Callable, List, Optional

from .facade_device_type import FacadeDeviceType
from .facade_error_code import FacadeError, FacadeErrorCode
from .libfacade import ffi, libfacade


class FacadeDevice(metaclass=ABCMeta):
    """
    A virtual device managed by Facade's system software.

    To stream media from or to the device, you must cast a device to
    :py:class:`VideoFacadeDevice`
    """

    def __init__(self, pointer):
        self.__read_callback = None
        self.__write_callback = None
        self.__changed_callback = None
        self._pointer = pointer

    def __str__(self) -> str:
        return f"FacadeDevice{{uid={self.uid}}}"

    def __del__(self):
        double_pointer = ffi.new(cdecl='facade_device**', init=self._pointer)
        libfacade.facade_dispose_device(double_pointer)

    @property
    @abstractmethod
    def type(self) -> FacadeDeviceType:
        """
        The type of this device. This can be used to safely cast this device
        into a :py:class:`VideoFacadeDevice`.
        """

        pass

    @property
    def uid(self) -> int:
        """
        A globally unique identifier for this device. This can be used to distinguish
        it from other devices on a system.
        """

        return self._pointer.uid

    def read_callback(self, value: Callable[[], None]) -> None:
        """
        Register a callback for new data has become available from this device, for example,
        when a new video frame is pushed.

        :note: You must :func:`open` this device in read mode to use a read callback.
        :param value: The callback to notify when the device is ready to read from.
        """

        if value is None:
            self.__read_callback = None
            libfacade.facade_read_callback(self._pointer, ffi.NULL, ffi.NULL)
        else:
            def trap(_arg0):
                value()
            callback = ffi.callback(cdecl=ffi.typeof("void(*)(void *)"),
                                    python_callable=trap)
            self.__read_callback = callback
            libfacade.facade_read_callback(self._pointer, callback, ffi.NULL)

    def write_callback(self, value: Callable[[], None]) -> None:
        """
        Register a callback to be called when the device is ready to accept new data, for example,
        when the next video frame can be pushed.

        :note: You must :func:`open` this device in write mode to use a write callback.
        :note: You must push a frame manually after register your callback to kickstart the write loop. Otherwise,
            the device will not ask for the next frame.
        :param value: The callback to notify when the device is ready to write to.
        """

        if value is None:
            self.__write_callback = None
            libfacade.facade_write_callback(self._pointer, ffi.NULL, ffi.NULL)
        else:
            def trap(_arg0):
                value()
            callback = ffi.callback(cdecl=ffi.typeof("void(*)(void *)"),
                                    python_callable=trap)
            self.__write_callback = callback
            libfacade.facade_write_callback(self._pointer, callback, ffi.NULL)

    def changed_callback(self, value: Callable[[], None]) -> None:
        """
        Register a callback to be notified when this device's properties have been modified.

        :param value: The callback to notify when the device is modified.
        """

        if value is None:
            self.__changed_callback = None
            libfacade.facade_on_device_changed(self._pointer, ffi.NULL, ffi.NULL)
        else:
            def trap(_arg0):
                value()
            callback = ffi.callback(cdecl=ffi.typeof("void(*)(void *"),
                                    python_callable=trap)
            self.__changed_callback = callback
            libfacade.facade_on_device_changed(self._pointer, callback, ffi.NULL)

    def open(self, mode: Union[Literal['r'], Literal['w']]) -> None:
        """
        Open the device for reading or writing exclusively. You cannot both read and write
        to the same device.

        :param mode: "r" for read mode, "w" for write mode.
        """

        if 'r' in mode:
            code = libfacade.facade_read_open(self._pointer)
            if code != FacadeErrorCode.none:
                raise FacadeError('facade_read_open', code)
        elif 'w' in mode:
            code = libfacade.facade_write_open(self._pointer)
            if code != FacadeErrorCode.none:
                raise FacadeError('facade_write_open', code)

    def close(self) -> None:
        """
        Close the device. This will clean up system resources.
        """
        libfacade.facade_read_close(self._pointer)
        libfacade.facade_write_close(self._pointer)

    @staticmethod
    def create(device) -> 'FacadeDevice':
        """
        Create a device from its C pointer.

        :param device: The CFFI C pointer to the underlying ``facade_device``.
        :return: A concrete :py:class:`FacadeDevice` instance.
        """
        from .video_facade_device import VideoFacadeDevice
        return VideoFacadeDevice(device) if device.type == 0 else FacadeDevice(device)

    @staticmethod
    def by_uid(uid: int) -> Optional['FacadeDevice']:
        """
        Find a device by its :attr:`uid`

        :param uid: The uid of the device to find.
        :return: The :py:class:`FacadeDevice`  if found; otherwise ``None``.
        """

        pointer = ffi.new(cdecl='facade_device**', init=ffi.NULL)
        code = libfacade.facade_find_device_by_uid(uid.encode(), pointer)

        if code != FacadeErrorCode.none:
            raise FacadeError(invocation="facade_find_device_by_uid", code=code)

        return FacadeDevice.create(pointer[0])

    @staticmethod
    def by_name(name: str) -> Optional['FacadeDevice']:
        """
        Find a device by name

        :param name: The name of the device
        :return: The :py:class:`FacadeDevice` if found; otherwise ``None``.
        """

        pointer = ffi.new(cdecl='facade_device**', init=ffi.NULL)
        code = libfacade.facade_find_device_by_name(name.encode(), pointer)

        if code != FacadeErrorCode.none:
            raise FacadeError(invocation="facade_find_device_by_name", code=code)

        return FacadeDevice.create(pointer[0])

    @staticmethod
    def list() -> List['FacadeDevice']:
        """
        List all devices managed by Facade

        :return: A list of devices virtualized by Facade
        """
        list_head = ffi.new('facade_device **')
        libfacade.facade_list_devices(list_head)
        devices = []

        node = list_head[0]
        visited = False

        while node != ffi.NULL and (node != list_head[0] or not visited):
            devices.append(FacadeDevice.create(node))
            node = node.next
            visited = True

        return devices
