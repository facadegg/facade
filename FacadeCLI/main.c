//
//  main.c
//  FacadeCLI
//
//  Created by Shukant Pal on 1/29/23.
//

#include "FacadeKit.h"
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
        if (node->type == video_facade)
            printf("Camera{uid=%lli}\n", node->uid);
    } while (node != *list);
}

uint8_t *buf = NULL;
size_t buff_size = 0;

void read_device(void *context) {
    facade_device *device = (facade_device *) context;
    facade_read(device, (void **) &buf, &buff_size);
}

void write_device(void *context) {
    if (buf == NULL) {
        printf("Buffer not filled yet \n");
        return;
    }
    
    printf("Write");
    
    for (int i = 0; i < buff_size; i += 4)
    {
        buf[i + 1] = 0;
        buf[i + 2] = 0;
    }
    
    facade_write((facade_device *) context, buf, buff_size);
}

int main(int argv, char **argc) {
    facade_device *list = NULL;
    
    facade_init();
    facade_list_devices(&list);
    facade_reader(list, &read_device, list);
    
    print_devices(&list);
    
    printf("dimensions %i x %i\n", list->width, list->height);
    printf("rate %i\n", list->frame_rate);
    
    facade_reader(list, nil, list);
    facade_writer(list, nil, list);
    buf = calloc(4 * 1920 * 1080, 1);
    buff_size = 4 * 1920 * 1080;

    while(true) {
        read_device(list);
        write_device(list);
        usleep(16000);
    }
    printf("Success\n");
}
