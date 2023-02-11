from typing import Optional

from .facade_device import FacadeDevice
from .facade_device_type import FacadeDeviceType
from .facade_error_code import FacadeError, FacadeErrorCode
from .libfacade import ffi, libfacade


class VideoFacadeDevice(FacadeDevice):
    def __str__(self) -> str:
        return f"FacadeDevice{{uid={self.uid} width={self.width}, height={self.width}, frame_rate={self.frame_rate}}}"

    @property
    def type(self) -> FacadeDeviceType:
        return FacadeDeviceType.video

    @property
    def width(self) -> int:
        return self._pointer.width

    @property
    def height(self) -> int:
        return self._pointer.height

    @property
    def frame_rate(self) -> int:
        return self._pointer.frame_rate

    @property
    def frame_byte_size(self) -> int:
        return self.width * self.height * 4

    def read_frame(self, buffer: Optional[bytearray]) -> Optional[ffi.buffer]:
        if buffer is None:
            buffer_size = self.frame_byte_size
            native_buffer = ffi.new(f'uint8_t[{buffer_size}]')
        else:
            if len(buffer) < self.frame_byte_size:
                raise ValueError(f"buffer is too small (minimum size is {self.frame_byte_size})")
            buffer_size = len(buffer)
            native_buffer = ffi.from_buffer(cdecl='uint8_t *', python_buffer=buffer)

        code = libfacade.facade_read(self._pointer, native_buffer, buffer_size)

        if code not in (FacadeErrorCode.none, FacadeErrorCode.reader_not_ready):
            raise FacadeError('facade_read_frame', code)

        return ffi.buffer(native_buffer) if code == FacadeErrorCode.none else None

    def write_frame(self, buffer: Optional[bytearray]):
        buffer_size = self.width * self.height * 4
        if len(buffer) < buffer_size:
            raise ValueError("buffer is of wrong size")

        code = libfacade.facade_write_frame(self._pointer, ffi.from_buffer('void *', buffer), len(buffer))

        if code != FacadeErrorCode.none:
            raise FacadeError('facade_write_frame', code)
