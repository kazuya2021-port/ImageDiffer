//
//  psd_writer.c
//  KZPSDWriter
//
//  Created by uchiyama_Macmini on 2020/03/11.
//  Copyright © 2020年 uchiyama_Macmini. All rights reserved.
//

#include "psd_writer.h"

// ============== inline method ==============
inline static void
psdBufferDataDestroy(uint8_t **buffer)
{
    if (psd_is_not_null(*buffer)) {
        free(*buffer);
        *buffer = PSD_NULL;
    }
}

psd_header_t* psdHeaderCreate(psd_uint32_t width, psd_uint32_t height, psd_bool_t hasAlpha)
{
    psd_header_t *header = calloc(1, sizeof(psd_header_t));
    
    header->signature = PSD_MAKE_TAG('8', 'B', 'P', 'S');
    header->version = 1;
    header->num_channels;
}

void psdHeaderDestroy(psd_header_t *header)
{
    if (psd_is_not_null(header)) {
        psdBufferDataDestroy(&header->color_mode_data);
        free(header);
    }
}
