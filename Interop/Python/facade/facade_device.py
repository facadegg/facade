from typing import Union, Literal

from .facade_error_code import FacadeError, FacadeErrorCode
from .libfacade import ffi, libfacade


class FacadeDevice:
    def __init__(self, pointer):
        self._pointer = pointer

    def __str__(self):
        return f"FacadeDevice{{uid={self.uid}}}"

    @property
    def uid(self):
        return self._pointer.uid

    def open(self, mode: Union[Literal['r'], Literal['w']]):
        if 'r' in mode:
            code = libfacade.facade_read_open(self._pointer)
            if code != FacadeErrorCode.none:
                raise FacadeError('facade_read_open', code)
        elif 'w' in mode:
            code = libfacade.facade_write_open(self._pointer)
            if code != FacadeErrorCode.none:
                raise FacadeError('facade_write_open', code)

    def close(self):
        libfacade.facade_read_close(self._pointer)
        libfacade.facade_write_close(self._pointer)

    @staticmethod
    def create(device) -> 'FacadeDevice':

        from .video_facade_device import VideoFacadeDevice
        return VideoFacadeDevice(device) if device.type == 0 else FacadeDevice(device)

    @staticmethod
    def list():
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
