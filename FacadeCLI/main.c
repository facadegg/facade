//
//  main.c
//  FacadeCLI
//
//  Created by Shukant Pal on 1/29/23.
//

#include "FacadeKit.h"
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

char *buf = NULL;

void write_nil(facade_device *device)
{
    if (buf == NULL) {
        buf = malloc(1920 * 1080 * sizeof(uint32_t));
    }

    for (int y = 0; y < 1080; y++) {
        for (int x = 0; x < 1920; x++) {
            buf[(y * 1920 + x) * 4] = 0xff;
            buf[(y * 1920 + x) * 4 + 1] = 0xaa;
            buf[(y * 1920 + x) * 4 + 2] = 0xaa;
            buf[(y * 1920 + x) * 4 + 3] = 0xff;
        }
    }
    
    printf("\n%id\n", facade_write(device, buf, NULL, NULL));
}

int main(int argv, char **argc) {
    facade_device *list = NULL;
    
    facade_init();
    facade_list_devices(&list);
    
    print_devices(&list);
    
    while(1) {
        write_nil(list);
        usleep(16000);
    }
    
    printf("Success\n");
}
