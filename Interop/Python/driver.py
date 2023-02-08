from time import sleep

if __name__ == "__main__":
    import facade

    devices = facade.FacadeDevice.list()
    print(*facade.FacadeDevice.list())
    buffer = bytearray(devices[0].width * devices[0].height * 4)
    i = 0

    while True:
        buffer[i] = 255
        buffer[i + 1] = 255
        buffer[i + 2] = 255
        buffer[i + 3] = 255
        i += 4
        i %= len(buffer)
        devices[0].write(buffer)
        sleep(.016)
