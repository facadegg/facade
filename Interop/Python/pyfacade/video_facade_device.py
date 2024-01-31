from typing import Optional

from .facade_device import FacadeDevice
from .facade_device_type import FacadeDeviceType
from .facade_error_code import FacadeError, FacadeErrorCode
from .libfacade import ffi, libfacade


class VideoFacadeDevice(FacadeDevice):
    """
    A :py:class:`FacadeDevice` device that is a virtual camera. It streams video
    frames in a 8-bit/channel RGBA pixel format.
    """

    def __str__(self) -> str:
        return f"FacadeDevice{{uid={self.uid} width={self.width}, height={self.width}, frame_rate={self.frame_rate}}}"

    @property
    def type(self) -> FacadeDeviceType.video:
        return FacadeDeviceType.video

    @property
    def width(self) -> int:
        """
        The width, in pixels, of video.
        """

        return self._pointer.width

    @property
    def height(self) -> int:
        """
        The height, in pixels, of video.
        """

        return self._pointer.height

    @property
    def frame_rate(self) -> int:
        """
        The (maximum) frames per second this device will consume.
        """

        return self._pointer.frame_rate

    @property
    def frame_byte_size(self) -> int:
        """
        The size of a single frame, in bytes.
        """

        return self.width * self.height * 4

    def read_frame(self, buffer: Optional[bytearray]) -> Optional[ffi.buffer]:
        """
        Reads the next video frame.

        :param buffer: A buffer, of size :attr:`frame_byte_size`, to copy the video frame into. This can
            be used to optimize memory consumed by this operation.
        :return: A buffer containing the video frame pixels, if the device had a frame buffered. Otherwise, ``None``.
        """

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
        """
        Writes the next video frame.

        :param buffer: A buffer, of size :attr:`frame_byte_size`, to copy the video frame from.
        :raises FacadeError: If the device is not ready for the next frame.
        """

        buffer_size = self.width * self.height * 4
        if len(buffer) < buffer_size:
            raise ValueError("buffer is of wrong size")

        code = libfacade.facade_write_frame(self._pointer, ffi.from_buffer('void *', buffer), len(buffer))

        if code != FacadeErrorCode.none:
            raise FacadeError('facade_write_frame', code)
