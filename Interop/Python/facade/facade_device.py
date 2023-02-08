from libfacade import ffi, libfacade


class FacadeDevice:
    def __init__(self, pointer):
        self.__pointer = pointer

    @property
    def uid(self):
        return self.__pointer.uid

    @property
    def width(self):
        return self.__pointer.width

    @property
    def height(self):
        return self.__pointer.height

    @property
    def frame_rate(self):
        return self.__pointer.frame_rate

    def __str__(self):
        return f"FacadeDevice{{uid={self.uid} width={self.width}, height={self.width}, frame_rate={self.frame_rate}}}"

    def read(self):
        pass

    def reader(self):
        pass

    def write(self):
        pass

    def writer(self):
        pass

    @staticmethod
    def create(device) -> 'FacadeDevice':
        return FacadeDevice(device)

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


if __name__ == "__main__":
    print(*FacadeDevice.list())
