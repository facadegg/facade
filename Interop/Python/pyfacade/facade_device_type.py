from enum import IntEnum


class FacadeDeviceType(IntEnum):
    """
    The types of devices that can be virtualized by Facade.
    """

    video = 0
    """
    A video device (virtual camera).
    """