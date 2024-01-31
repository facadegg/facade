import time
import typing

from facade import *

facade_init()

device = FacadeDevice.list()[0]
camera = typing.cast(VideoFacadeDevice, device)
camera.open(mode='w')

pixel_buffer = bytearray(camera.width * camera.height * 4)
clear_line = [0 for i in range(0, camera.width * 4)]
white_line = [255 for i in range(0, camera.width * 4)]
line_idx = 0


def render():
    global line_idx, pixel_buffer, camera

    pixel_buffer[line_idx:line_idx + camera.width * 4] = clear_line
    line_idx = (line_idx + camera.width * 4) % len(pixel_buffer)
    pixel_buffer[line_idx:line_idx + camera.width * 4] = white_line

    camera.write_frame(pixel_buffer)


if __name__ == "__main__":
    camera.write_callback(render)
    render()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        camera.close()