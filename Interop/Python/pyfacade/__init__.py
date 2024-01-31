from .facade_device import FacadeDevice
from .facade_device_type import FacadeDeviceType
from .facade_error_code import FacadeError, FacadeErrorCode
from .video_facade_device import VideoFacadeDevice
from .libfacade import libfacade


def facade_init():
    """
    Initialize the Facade library.

    This must be called at application initialization. If pyfacade is used without calling ``facade_init``,
    it will result in undefined behavior.
    """

    libfacade.facade_init()