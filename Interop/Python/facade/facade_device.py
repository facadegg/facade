from .libfacade import ffi, libfacade


class FacadeDevice:
    def __init__(self, pointer):
        self._pointer = pointer

    def __str__(self):
        return f"FacadeDevice{{uid={self.uid}}}"

    @property
    def uid(self):
        return self._pointer.uid

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
