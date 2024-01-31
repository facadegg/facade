from .facade_device import *
from .facade_device_type import *
from .facade_error_code import *
from .video_facade_device import *
from .libfacade import libfacade


def facade_init():
    """
    Initialize the Facade library.

    This must be called at application initialization. If pyfacade is used without calling \c init,
    it will result in undefined behavior.
    """
    libfacade.facade_init()