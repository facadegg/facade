import time
from time import sleep

from facade.facade_error_code import FacadeError
from facade.libfacade import libfacade, ffi

if __name__ == "__main__":
    import facade
    libfacade.facade_init()

    devices = [facade.FacadeDevice.by_name("Facade")]
    print(*devices)
    devices[0].open('w')
    buffer = bytearray(devices[0].width * devices[0].height * 4)
    clear = [0 for i in range(0, devices[0].width * 4)]
    row = [255 for i in range(0, devices[0].width * 4)]
    i = 0
    t = time.perf_counter()

    def write_callback():
        global i, buffer, devices, t

        buffer[i:i+devices[0].width * 4] = clear
        i += devices[0].width * 4
        i %= len(buffer)
        buffer[i:i+devices[0].width * 4] = row

        try:
            devices[0].write_frame(buffer)
            print((time.perf_counter() - t) * 1000)
            t = time.perf_counter()
        except FacadeError as e:
            print(e)

    devices[0].write_callback(write_callback)
    write_callback()

    while True:
        sleep(.1)

