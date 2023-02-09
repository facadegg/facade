from time import sleep

from facade.facade_error_code import FacadeError
from facade.libfacade import libfacade

if __name__ == "__main__":
    import facade
    libfacade.facade_init()

    devices = facade.FacadeDevice.list()
    print(*devices)
    devices[0].open('w')
    buffer = bytearray(devices[0].width * devices[0].height * 4)
    i = 0

    while True:
        buffer[i] = 255
        buffer[i + 1] = 255
        buffer[i + 2] = 255
        buffer[i + 3] = 255
        i += 4
        i %= len(buffer)
        try:
            devices[0].write_frame(buffer)
        except FacadeError as e:
            print(e)
        sleep(.1)
