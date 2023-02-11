from abc import ABCMeta, abstractmethod
from typing import Union, Literal, Callable, List, Optional

from .facade_device_type import FacadeDeviceType
from .facade_error_code import FacadeError, FacadeErrorCode
from .libfacade import ffi, libfacade


class FacadeDevice(metaclass=ABCMeta):
    def __init__(self, pointer):
        self.__read_callback = None
        self.__write_callback = None
        self._pointer = pointer

    def __str__(self) -> str:
        return f"FacadeDevice{{uid={self.uid}}}"

    @property
    @abstractmethod
    def type(self) -> FacadeDeviceType:
        pass

    @property
    def uid(self) -> int:
        return self._pointer.uid

    def read_callback(self, value: Callable[[], None]) -> None:
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

    def open(self, mode: Union[Literal['r'], Literal['w']]) -> None:
        if 'r' in mode:
            code = libfacade.facade_read_open(self._pointer)
            if code != FacadeErrorCode.none:
                raise FacadeError('facade_read_open', code)
        elif 'w' in mode:
            code = libfacade.facade_write_open(self._pointer)
            if code != FacadeErrorCode.none:
                raise FacadeError('facade_write_open', code)

    def close(self) -> None:
        libfacade.facade_read_close(self._pointer)
        libfacade.facade_write_close(self._pointer)

    @staticmethod
    def create(device) -> 'FacadeDevice':
        from .video_facade_device import VideoFacadeDevice
        return VideoFacadeDevice(device) if device.type == 0 else FacadeDevice(device)

    @staticmethod
    def by_id(_id: int) -> Optional['FacadeDevice']:
        pass

    @staticmethod
    def by_name(_name: str) -> Optional['FacadeDevice']:
        pass

    @staticmethod
    def list() -> List['FacadeDevice']:
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
