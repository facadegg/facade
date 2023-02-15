//
//  main.c
//  FacadeCLI
//
//  Created by Shukant Pal on 1/29/23.
//

#include "facade.h"
#include <CoreFoundation/CoreFoundation.h>
#include <memory.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

void print_devices(facade_device **list) {
    if (*list == NULL)
    {
        printf("Note: No devices!\n");
        return;
    }

    facade_device *node = *list;
    do {
        if (node->type == facade_type_video)
            printf("Camera{uid=%lli}\n", node->uid);
    } while (node != *list);
}

uint8_t *buf = NULL;
size_t buff_size = 0;

void read_device(void *context) {
    facade_device *device = (facade_device *) context;
    facade_read_frame(device, (void **) &buf, &buff_size);
}

void write_device(void *context) {
    if (buf == NULL) {
        printf("Buffer not filled yet \n");
        return;
    }

    for (int i = 0; i < buff_size; i += 4)
    {
        buf[i + 1] = 255;
        buf[i + 2] = 0;
    }

    facade_error_code status = facade_write_frame((facade_device *) context, buf, buff_size);

    printf("Write %i\n", status);
}

int main(int argv, char **argc) {
    facade_device *list = NULL;
    facade_state *output;

    facade_init();
    facade_read_state(&output);
    
    printf("Parsed state %lli ", output->api_version);
    
    facade_device_info *next = calloc(1, sizeof(facade_device_info));
    
    next->name = "Facade2";
    next->width = 480;
    next->height = 360;
    next->frame_rate = 30;
    
    output->devices->next = next;
    next->next = output->devices;
    
    facade_write_state(output);

//    print_devices(&list);
//    facade_device * device = list;
//
//    printf("dimensions %i x %i\n", list->width, list->height);
//    printf("rate %i\n", list->frame_rate);
//
//    buf = calloc(4 * device->height * device->width, 1);
//    buff_size = 4 * device->width * device->height;
//    printf("buff_size is %li", buff_size);
//
//
//    facade_write_open(list);
//
//    while(true) {
//        // read_device(list);
//        write_device(list);
//        usleep(16000);
//    }
//    printf("Success\n");
}
