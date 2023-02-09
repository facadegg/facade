from typing import Optional

from .facade_device import FacadeDevice
from .facade_error_code import FacadeError, FacadeErrorCode
from .libfacade import ffi, libfacade


class VideoFacadeDevice(FacadeDevice):
    @property
    def width(self):
        return self._pointer.width

    @property
    def height(self):
        return self._pointer.height

    @property
    def frame_rate(self):
        return self._pointer.frame_rate

    def read_frame(self) -> Optional[ffi.buffer]:
        buffer_size = self.width * self.height * 4
        buffer = ffi.new(f'uint8_t[{buffer_size}]')
        code = libfacade.facade_read(self._pointer, buffer, buffer_size)

        if code not in (FacadeErrorCode.none, FacadeErrorCode.reader_not_ready):
            raise FacadeError('facade_read_frame', code)

        return ffi.buffer(buffer) if code == FacadeErrorCode.none else None

    def write_frame(self, buffer: Optional[bytearray]):
        buffer_size = self.width * self.height * 4
        if len(buffer) < buffer_size:
            raise ValueError("buffer is of wrong size")

        code = libfacade.facade_write_frame(self._pointer, ffi.from_buffer('void *', buffer), len(buffer))

        if code != FacadeErrorCode.none:
            raise FacadeError('facade_write_frame', code)

    def __str__(self):
        return f"FacadeDevice{{uid={self.uid} width={self.width}, height={self.width}, frame_rate={self.frame_rate}}}"

