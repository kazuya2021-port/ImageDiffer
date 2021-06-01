//
//  psd.cpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/09.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#include <stdlib.h>
#include <iostream>
#include <string>
#include <png.h>
#include "psd.hpp"

static png_structp png_ptr;
static png_infop info_ptr;

const char *channelsuffixes[] = {
    "", "", "", "RGB",
    "CMYK", "HSL", "HSB", "",
    "", "Lab", "", "RGB",
    "Lab", "CMYK", "", ""
};

const char *comptype[] = {"raw", "RLE", "ZIP without prediction", "ZIP with prediction"};

struct psd_header{
    char sig[4];
    unint16 version;
    char reserved[6];
    unint16 channels;
    unint32 rows;
    unint32 cols;
    unint16 depth;
    int16 mode; // we use -1 as flag for 'scavenging' where actual mode is not known
    
    // following fields are for our purposes, not actual header fields
    psd_bytes_t colormodepos;
    psd_bytes_t resourcepos;
    int32 nlayers, mergedalpha; // set by dopsd()->dolayermaskinfo()
    struct layer_info *linfo;     // layer info array, set by dopsd()->dolayermaskinfo()
    psd_bytes_t lmistart, lmilen; // layer & mask info section, set by dopsd()->dolayermaskinfo()
    psd_bytes_t layerdatapos;
    psd_bytes_t global_lmi_pos, global_lmi_len;
    struct channel_info *merged_chans; // set by doimage()
};

struct layer_mask_info{
    psd_bytes_t size; // 36, 20, or zero
    
    // if size == 20:
    int32 top;
    int32 left;
    int32 bottom;
    int32 right;
    char default_colour;
    char flags;
    
    // if size == 36:
    char real_flags;
    char real_default_colour;
    int32 real_top;
    int32 real_left;
    int32 real_bottom;
    int32 real_right;
};

struct blend_mode_info{
    char sig[4];
    char key[4];
    unchar opacity;
    unchar clipping;
    unchar flags;
    //unsigned char filler;
};

struct channel_info{
    int32 id;                   // channel id
    int32 comptype;             // channel's compression type
    psd_pixels_t rows, cols, rowbytes;  // set by dochannel()
    psd_bytes_t length;       // channel byte count in file
    
    // used in rebuild
    psd_bytes_t length_rebuild; // channel byte count in file
    
    // how to find image data, depending on compression type:
    psd_bytes_t rawpos;       // file offset of RAW channel data (AFTER compression type)
    psd_bytes_t *rowpos;      // row data file positions (RLE ONLY)
    unchar *unzipdata; // uncompressed data (ZIP ONLY)
};

struct layer_info{
    int32 top;
    int32 left;
    int32 bottom;
    int32 right;
    int16 channels;
    
    // runtime data (not in file)
    struct channel_info *chan;
    int32 *chindex;    // lookup channel number by id (inverse of chid[])
    struct blend_mode_info blend;
    struct layer_mask_info mask;
    char *name;
    char *unicode_name; // utf8. will be NULL unless unicode_filenames or extra flags set
    char *nameno; // "layerNN"
    psd_bytes_t additionalpos;
    psd_bytes_t additionallen;
    
    psd_bytes_t filepos; // only used in scavenge layers mode
    psd_bytes_t chpos; // only used in scavenge channels mode
    
};

#pragma mark - Local Funcs
int16 read_2byte(FILE* f) {
    int16 n = fgetc(f) << 8;
    return n | fgetc(f);
}

unint16 read_2byteU(FILE* f) {
    unint16 n = fgetc(f) << 8;
    n = n | fgetc(f);
    return n < 0x8000 ? n : n - 0x10000;
}

int32 read_4byte(FILE* f) {
    int32 n = fgetc(f) << 24;
    n |= fgetc(f) << 16;
    n |= fgetc(f) << 8;
    return n | fgetc(f);
}

bool is_valid_header(struct psd_header *h) {
    return !(h->channels <= 0 || h->channels > 64 || h->rows <= 0
             || h->cols <= 0 || h->depth <= 0 || h->depth > 32 || h->mode < 0);
}

void skipblock(FILE* f, const char *desc) {
    
    psd_bytes_t n = read_4byte(f);
    if(n){
        fseeko(f, n, SEEK_CUR);
    }else
        std::cerr << "  (" << desc << " is empty)" << std::endl;
}

void readlayerinfo(FILE* f, struct psd_header *h, int i)
{
    psd_bytes_t extralen, extrastart;
    int j, chid, namelen;
    char *chidstr, tmp[10];
    struct layer_info *li = h->linfo + i;
    
    // process layer record
    li->top = read_4byte(f);
    li->left = read_4byte(f);
    li->bottom = read_4byte(f);
    li->right = read_4byte(f);
    li->channels = read_2byteU(f);
    
    if( li->bottom < li->top || li->right < li->left || li->channels > 64 ) {
        std::cerr << "### something's not right about that, trying to skip layer." << std::endl;
        fseeko(f, 6*li->channels+12, SEEK_CUR);
        skipblock(f, "layer info: extra data");
        li->chan = NULL;
        li->chindex = NULL;
        li->nameno = li->name = li->unicode_name = NULL;
    }
    else {
        li->chan = (struct channel_info*)malloc(li->channels*sizeof(struct channel_info));
        li->chindex = (int32*)malloc((li->channels+3)*sizeof(int32));
        li->chindex += 3; // so we can index array from [-3] (hackish)
        
        for(j = -3; j < li->channels; ++j)
            li->chindex[j] = -1;
        
        // fetch info on each of the layer's channels
        
        for(j = 0; j < li->channels; ++j){
            li->chan[j].id = chid = read_2byte(f);
            li->chan[j].length = read_4byte(f);
            li->chan[j].rawpos = 0;
            li->chan[j].rowpos = NULL;
            li->chan[j].unzipdata = NULL;
            
            if(chid >= -3 && chid < li->channels)
                li->chindex[chid] = j;
            else
                std::cerr << "unexpected channel id " << chid << std::endl;
            
            switch(chid){
                case UMASK_CHAN_ID: chidstr = (char*)" (user layer mask)"; break;
                case LMASK_CHAN_ID: chidstr = (char*)" (layer mask)"; break;
                case TRANS_CHAN_ID: chidstr = (char*)" (transparency mask)"; break;
                default:
                    if(h->mode != SCAVENGE_MODE && chid < (int)strlen(channelsuffixes[h->mode]))
                        sprintf(chidstr = tmp, " (%c)", channelsuffixes[h->mode][chid]); // it's a mode-ish channel
                    else
                        chidstr = (char *)""; // don't know
            }
        }
        
        fread(li->blend.sig, 1, 4, f);
        fread(li->blend.key, 1, 4, f);
        li->blend.opacity = fgetc(f);
        li->blend.clipping = fgetc(f);
        li->blend.flags = fgetc(f);
        fgetc(f); // padding
        
        // process layer's 'extra data' section
        
        extralen = read_4byte(f);
        extrastart = (psd_bytes_t)ftello(f);
        
        // fetch layer mask data
        li->mask.size = read_4byte(f);
        if(li->mask.size >= 20){
            off_t skip = li->mask.size;
            li->mask.top = read_4byte(f);
            li->mask.left = read_4byte(f);
            li->mask.bottom = read_4byte(f);
            li->mask.right = read_4byte(f);
            li->mask.default_colour = fgetc(f);
            li->mask.flags = fgetc(f);
            skip -= 18;
            if(li->mask.size >= 36){
                li->mask.real_flags = fgetc(f);
                li->mask.real_default_colour = fgetc(f);
                li->mask.real_top = read_4byte(f);
                li->mask.real_left = read_4byte(f);
                li->mask.real_bottom = read_4byte(f);
                li->mask.real_right = read_4byte(f);
                skip -= 18;
            }
            fseeko(f, skip, SEEK_CUR); // skip remainder
        }
        
        skipblock(f, "layer blending ranges");
        
        // layer name
        li->nameno = (char *)malloc(16);
        sprintf(li->nameno, "layer%d", i+1);
        namelen = fgetc(f);
        li->name = (char *)malloc(PAD4(namelen+1));
        fread(li->name, 1, PAD4(namelen+1)-1, f);
        li->name[namelen] = 0;
        if(namelen)
            std::cout << "    name: " << li->name << std::endl;
        
        // process layer's 'additional info'
        
        li->additionalpos = (psd_bytes_t)ftello(f);
        li->additionallen = extrastart + extralen - li->additionalpos;
        
        // leave file positioned after extra data
        fseeko(f, extrastart + extralen, SEEK_SET);
    }
}

bool dolayerinfo(FILE* f, struct psd_header *h){
    int i;
    
    // layers structure
    h->nlayers = read_2byte(f);
    h->mergedalpha = h->nlayers < 0;
    if(h->mergedalpha){
        h->nlayers = - h->nlayers;
        std::cout << "  (first alpha is transparency for merged image)" << std::endl;
    }
    std::cout << std::endl << h->nlayers << " layers:" << std::endl;
    size_t structSize = sizeof(struct layer_info);
    h->linfo = (struct layer_info*)malloc(h->nlayers*structSize);
    
    if (h->linfo == NULL) {
        std::cerr << "  (layer info data is not allocated!" << std::endl;
        return false;
    }
    // load linfo[] array with each layer's info
    
    for(i = 0; i < h->nlayers; ++i)
        readlayerinfo(f, h, i);
    
    return true;
}

bool dolayermaskinfo(FILE* f, struct psd_header *h){
    psd_bytes_t layerlen;
    
    h->nlayers = 0;
    h->lmilen = read_4byte(f);
    h->lmistart = (psd_bytes_t)ftello(f);
    if(h->lmilen){
        // process layer info section
        layerlen = read_4byte(f);
        if (layerlen) {
            if (!dolayerinfo(f, h)) {
                return false;
            }
            // after processing all layers, file should now positioned at image data
        }
        else {
            std::cout << "  (layer info section is empty)" << std::endl;
        }
    }
    else {
        std::cout << "  (layer & mask info section is empty)" << std::endl;
    }
    
    return true;
}

void dochannel(FILE* f,
               struct layer_info *li,
               struct channel_info *chan, // array of channel info
               int channels, // how many channels are to be processed (>1 only for merged data)
               struct psd_header *h)
{
    int compr, ch;
    psd_bytes_t chpos, pos;
    psd_pixels_t count, last, j, rb;
    
    chpos = (psd_bytes_t)ftello(f);
    
    if(li){
        // If this is a layer mask, the pixel size is a special case
        if(chan->id == LMASK_CHAN_ID){
            chan->rows = li->mask.bottom - li->mask.top;
            chan->cols = li->mask.right - li->mask.left;
        }else if(chan->id == UMASK_CHAN_ID){
            chan->rows = li->mask.real_bottom - li->mask.real_top;
            chan->cols = li->mask.real_right - li->mask.real_left;
        }else{
            // channel has dimensions of the layer
            chan->rows = li->bottom - li->top;
            chan->cols = li->right - li->left;
        }
    }else{
        // merged image, has dimensions of PSD
        chan->rows = h->rows;
        chan->cols = h->cols;
    }
    
    // Compute image row bytes
    rb = (psd_pixels_t)(((long)chan->cols*h->depth + 7)/8);
    
    // Read compression type
    compr = read_2byteU(f);
    
    if (compr != RLECOMP) {
        std::cerr << "support only RLE!" << std::endl;
        return;
    }
    else {
        pos = chpos + 2;
        pos += (channels*chan->rows) << h->version;
    }
    
    for(ch = 0; ch < channels; ++ch){
        if(!li){
            // if required, identify first alpha channel as merged data transparency
            chan[ch].id = h->mergedalpha && ch == mode_channel_count[h->mode]
            ? TRANS_CHAN_ID : ch;
        }
        chan[ch].rowbytes = rb;
        chan[ch].comptype = compr;
        chan[ch].rows = chan->rows;
        chan[ch].cols = chan->cols;
        chan[ch].rowpos = NULL;
        chan[ch].unzipdata = NULL;
        chan[ch].rawpos = 0;
        
        if(!chan->rows)
            continue;
        
        /* accumulate RLE counts, to make array of row start positions */
        chan[ch].rowpos = (psd_bytes_t *)malloc((chan[ch].rows+1)*sizeof(psd_bytes_t));
        last = chan[ch].rowbytes;
        for(j = 0; j < chan[ch].rows && !feof(f); ++j){
            count = h->version==1 ? read_2byteU(f) : (psd_pixels_t)read_4byte(f);
            
            if(count < 2 || count > 2*chan[ch].rowbytes)  // this would be impossible
                count = last; // make a guess, to help recover
            
            last = count;
            chan[ch].rowpos[j] = pos;
            pos += count;
        }
        if(j < chan[ch].rows){
            std::cerr << "# couldn't read RLE counts" << std::endl;
        }
        chan[ch].rowpos[j] = pos;
    }
    
    if(li && pos != chpos + chan->length) {
        std::cerr << "# channel data is " << (unsigned long)(pos - chpos) << " bytes, but length = " << (unsigned long)chan->length << std::endl;
    }
    
    fseeko(f, pos, SEEK_SET);
}
/*
void rawwriteimage(
                   FILE *raw,
                   psd_file_t psd,
                   struct layer_info *li,
                   struct channel_info *chan,
                   int chancount,
                   struct psd_header *h)
{
    psd_pixels_t j;
    unsigned char *inrow, *rlebuf;
    int i;
    
    rlebuf = checkmalloc(chan->rowbytes*2);
    inrow  = checkmalloc(chan->rowbytes);
    
    // write channels in a series of planes, not interleaved
    for(i = 0; i < chancount; ++i){
        UNQUIET("## rawwriteimage: channel %d\n", i);
        for(j = 0; j < chan[i].rows; ++j){
            // get row data
            readunpackrow(psd, chan, j, inrow, rlebuf);
            if((psd_pixels_t)fwrite(inrow, 1, chan[i].rowbytes, raw) != chan->rowbytes){
                alwayswarn("# error writing raw data, aborting\n");
                goto err;
            }
        }
    }
    
err:
    fclose(raw);
    free(rlebuf);
    free(inrow);
}
*/

/*
void pngwriteimage(
                   FILE *png,
                   psd_file_t psd,
                   struct layer_info *li,
                   struct channel_info *chan,
                   int chancount,
                   struct psd_header *h)
{
    psd_pixels_t i, j;
    uint16_t *q;
    unsigned char *rowbuf, *inrows[4], *rledata, *p;
    int ch, map[4];
    
    
    
    // buffer used to construct a row interleaving all channels (if required)
    rowbuf  = malloc(chan->rowbytes*chancount);
    
    // a buffer for RLE decompression (if required), we pass this to readunpackrow()
    rledata = checkmalloc(chan->rowbytes*2);
    
    // row buffers per channel, for reading non-interleaved rows
    for(ch = 0; ch < chancount; ++ch){
        inrows[ch] = checkmalloc(chan->rowbytes);
        // build mapping so that png channel 0 --> channel with id 0, etc
        // and png alpha --> channel with id -1
        map[ch] = li && chancount > 1 ? li->chindex[ch] : ch;
    }
    
    // find the alpha channel, if needed
    if(li && (chancount == 2 || chancount == 4)){
        if(li->chindex[-1] == -1)
            alwayswarn("### did not locate alpha channel??\n");
        else
            map[chancount-1] = li->chindex[-1];
    }
    
    //for( ch = 0 ; ch < chancount ; ++ch )
    //    alwayswarn("# channel map[%d] -> %d\n", ch, map[ch]);
    
    if( setjmp(png_jmpbuf(png_ptr)) )
    { // If we get here, libpng had a problem writing the file
        alwayswarn("### pngwriteimage: Fatal error in libpng\n");
        goto err;
    }
    
    for(j = 0; j < chan->rows; ++j){
        for(ch = 0; ch < chancount; ++ch){
            // get row data
            if(map[ch] < 0 || map[ch] >= chancount){
                warn_msg("bad map[%d]=%d, skipping a channel", ch, map[ch]);
                memset(inrows[ch], 0, chan->rowbytes); // zero out the row
            }else
                readunpackrow(psd, chan + map[ch], j, inrows[ch], rledata);
        }
        
        if(chancount > 1){ // interleave channels
            if(h->depth == 8)
                for(i = 0, p = rowbuf; i < chan->rowbytes; ++i)
                    for(ch = 0; ch < chancount; ++ch)
                        *p++ = inrows[ch][i];
            else
                for(i = 0, q = (uint16_t*)rowbuf; i < chan->rowbytes/2; ++i)
                    for(ch = 0; ch < chancount; ++ch)
                        *q++ = ((uint16_t*)inrows[ch])[i];
            
            png_write_row(png_ptr, rowbuf);
        }else
            png_write_row(png_ptr, inrows[0]);
    }
    
    png_write_end(png_ptr, NULL //info_ptr);
    
err:
    fclose(png);
    
    free(rowbuf);
    free(rledata);
    for(ch = 0; ch < chancount; ++ch)
        free(inrows[ch]);
    
    png_destroy_write_struct(&png_ptr, &info_ptr);
}
*/
/*
static void writeimage(FILE* psd, char *dir, char *name,
                       struct layer_info *li,
                       struct channel_info *chan,
                       int channels, long rows, long cols,
                       struct psd_header *h, int color_type)
{
    FILE *outfile;
    
    if(h->depth == 32){
        if((outfile = rawsetupwrite(psd, dir, name, cols, rows, channels, color_type, li, h)))
            rawwriteimage(outfile, psd, li, chan, channels, h);
    }else{
        if((outfile = pngsetupwrite(psd, dir, name, cols, rows, channels, color_type, li, h)))
            pngwriteimage(outfile, psd, li, chan, channels, h);
    }
}*/

psd_pixels_t unpackbits(unsigned char *outp, unsigned char *inp,
                        psd_pixels_t outlen, psd_pixels_t inlen)
{
    psd_pixels_t i, len;
    int val;
    
    /* i counts output bytes; outlen = expected output size */
    for(i = 0; inlen > 1 && i < outlen;){
        /* get flag byte */
        len = *inp++;
        --inlen;
        
        if(len == 128) /* ignore this flag value */
            ; // warn_msg("RLE flag byte=128 ignored");
        else{
            if(len > 128){
                len = 1+256-len;
                
                /* get value to repeat */
                val = *inp++;
                --inlen;
                
                if((i+len) <= outlen)
                    memset(outp, val, len);
                else{
                    memset(outp, val, outlen-i); // fill enough to complete row
                    std::cout << "unpacked RLE data would overflow row (run)" << std::endl;
                    len = 0; // effectively ignore this run, probably corrupt flag byte
                }
            }else{
                ++len;
                if((i+len) <= outlen){
                    if(len > inlen)
                        break; // abort - ran out of input data
                    /* copy verbatim run */
                    memcpy(outp, inp, len);
                    inp += len;
                    inlen -= len;
                }else{
                    memcpy(outp, inp, outlen-i); // copy enough to complete row
                    std::cout << "unpacked RLE data would overflow row (copy)" << std::endl;
                    len = 0; // effectively ignore
                }
            }
            outp += len;
            i += len;
        }
    }
    if(i < outlen)
        std::cout << "not enough RLE data for row" << std::endl;

    return i;
}

void readunpackrow(FILE* psd,           // input file handle
                   struct channel_info *chan, // channel info
                   psd_pixels_t row,      // row index
                   unsigned char *inrow,  // dest buffer for the uncompressed row (rb bytes)
                   unsigned char *rlebuf) // temporary buffer for compressed data, 2 x rb in size
{
    psd_pixels_t n = 0, rlebytes;
    psd_bytes_t pos;
    int seekres = 0;

    if(chan->rowpos){
        pos = chan->rowpos[row];
        seekres = fseeko(psd, pos, SEEK_SET);
        if(seekres != -1){
            rlebytes = (psd_pixels_t)fread(rlebuf, 1, chan->rowpos[row+1] - pos, psd);
            n = unpackbits(inrow, rlebuf, chan->rowbytes, rlebytes);
        }
    }else{
        std::cout << "# readunpackrow() called for RLE data, but rowpos is NULL" << std::endl;
    }
    
    // if we don't recognise the compression type, skip the row
    // FIXME: or would it be better to use the last valid type seen?
    
    if(seekres == -1)
        std::cout << "# can't seek" << std::endl;
    
    if(n < chan->rowbytes){
        std::cout << "row data short (wanted " << chan->rowbytes << ", got " << n << " bytes)" << std::endl;
        // zero out unwritten part of row
        memset(inrow + n, 0xff, chan->rowbytes - n);
    }
}

void EncoderWriteCallback(png_structp png, png_bytep data, png_size_t size) {
    LayerInfo* state = static_cast<LayerInfo*>(png_get_io_ptr(png));
    if (state->data == nullptr) {
        state->data = malloc(size);
        state->length = size;
    }
    else {
        state->pushBuf(data, sizeof(char), size / sizeof(char));
    }
}

void FakeFlushCallback(png_structp png) {
    // We don't need to perform any flushing since we aren't doing real IO, but
    // we're required to provide this function by libpng.
}

LayerInfo doimage(FILE* f, struct layer_info *li, char *name, struct psd_header *h)
{
    LayerInfo theLay = LayerInfo();
    int split = 0;
    // map channel count to a suitable PNG mode (when scavenging and actual mode is not known)
    static int png_mode[] = {0, PNG_COLOR_TYPE_GRAY, PNG_COLOR_TYPE_GRAY_ALPHA,
        PNG_COLOR_TYPE_RGB,  PNG_COLOR_TYPE_RGB_ALPHA};
    int ch, pngchan = 0, color_type = 0, has_alpha = 0,
    channels = li ? li->channels : h->channels;
    psd_bytes_t image_data_end;
    
    if(h->mode == SCAVENGE_MODE){
        pngchan = channels;
        color_type = png_mode[pngchan];
    }
    else{
        has_alpha = li ? li->chindex[TRANS_CHAN_ID] != -1
        : h->mergedalpha && channels > mode_channel_count[h->mode];
        pngchan = mode_channel_count[h->mode] + has_alpha;
        
        switch(h->mode){
            default: // multichannel, cmyk, lab etc
                split = 1;
            case ModeBitmap:
            case ModeGrayScale:
            case ModeGray16:
            case ModeDuotone:
            case ModeDuotone16:
                color_type = has_alpha ? PNG_COLOR_TYPE_GRAY_ALPHA : PNG_COLOR_TYPE_GRAY;
                break;
            case ModeIndexedColor:
                color_type = PNG_COLOR_TYPE_PALETTE;
                break;
            case ModeRGBColor:
            case ModeRGB48:
                color_type = has_alpha ? PNG_COLOR_TYPE_RGB_ALPHA : PNG_COLOR_TYPE_RGB;
                break;
        }
    }
    
    if (li) {
        for (ch = 0; ch < channels; ++ch) {
            dochannel(f, li, li->chan + ch, 1, h);
        }
        image_data_end = (psd_bytes_t)ftello(f);
        
        // write png to buffer
        long rows = li->bottom - li->top;
        long cols = li->right - li->left;
        
        unsigned char *rowbuf = nullptr, *inrows[4], *rledata = nullptr, *p = nullptr;
        
        if (pngchan && !split) {
            if ((cols && rows) && !(pngchan < 1) && !(pngchan > 4)) {
                if( !(png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL)) ){
                    std::cout << "### pngsetupwrite: png_create_write_struct failed" << std::endl;
                    return LayerInfo();
                }
                if( !(info_ptr = png_create_info_struct(png_ptr)) ) {
                    std::cout << "### pngsetupwrite: Fatal error in libpng" << std::endl;
                    return LayerInfo();
                }
                
                png_set_IHDR(png_ptr, info_ptr, cols, rows, h->depth, color_type,
                             PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
                
                png_set_compression_level(png_ptr, 9);
                png_write_info((const png_structp) png_ptr,(const png_infop)info_ptr);
                theLay.name = name;
                psd_pixels_t i, j;
                uint16_t *q;
                
                int ch, map[4];
                bool iserr = false;
                
                // buffer used to construct a row interleaving all channels (if required)
                rowbuf  = (unsigned char *)malloc(li->chan->rowbytes*pngchan);
                rledata = (unsigned char *)malloc(li->chan->rowbytes*2);
                for (ch = 0; ch < pngchan; ++ch) {
                    inrows[ch] = (unsigned char *)malloc(li->chan->rowbytes);
                    // build mapping so that png channel 0 --> channel with id 0, etc
                    // and png alpha --> channel with id -1
                    map[ch] = li && pngchan > 1 ? li->chindex[ch] : ch;
                }
                
                // find the alpha channel, if needed
                if (li && (pngchan == 2 || pngchan == 4)){
                    if (li->chindex[-1] == -1) {
                        std::cout << "### did not locate alpha channel??" << std::endl;
                    }
                    else {
                        map[pngchan-1] = li->chindex[-1];
                    }
                }
                
                if( setjmp(png_jmpbuf(png_ptr)) )
                { /* If we get here, libpng had a problem writing the file */
                    std::cout << "### pngwriteimage: Fatal error in libpng" << std::endl;
                    iserr = true;
                    goto err;
                }
                png_set_write_fn(png_ptr, &theLay, EncoderWriteCallback, FakeFlushCallback);
                
                for(j = 0; j < li->chan->rows; ++j){
                    for(ch = 0; ch < pngchan; ++ch){
                        /* get row data */
                        if(map[ch] < 0 || map[ch] >= pngchan){
                            std::cout << "bad map[" << ch << "]=" << map[ch] << ", skipping a channel" << std::endl;
                            memset(inrows[ch], 0, li->chan->rowbytes); // zero out the row
                        }else
                            readunpackrow(f, li->chan + map[ch], j, inrows[ch], rledata);
                    }
                    
                    if(pngchan > 1){ /* interleave channels */
                        if(h->depth == 8)
                            for(i = 0, p = rowbuf; i < li->chan->rowbytes; ++i)
                                for(ch = 0; ch < pngchan; ++ch)
                                    *p++ = inrows[ch][i];
                        else
                            for(i = 0, q = (uint16_t*)rowbuf; i < li->chan->rowbytes/2; ++i)
                                for(ch = 0; ch < pngchan; ++ch)
                                    *q++ = ((uint16_t*)inrows[ch])[i];
                        
                        png_write_row(png_ptr, rowbuf);
                    }else
                        png_write_row(png_ptr, inrows[0]);
                }
                
                
            err:
                if(iserr) theLay.freeBuf();
                
                free(rowbuf);
                free(rledata);
                for(ch = 0; ch < pngchan; ++ch)
                    free(inrows[ch]);
                
                png_destroy_write_struct(&png_ptr, &info_ptr);
            }
        }
    
    }

    return theLay;
}

#pragma mark - Class Funcs
psd::psd () {
}

psd::~psd() {
    free(layer_data);
    fclose(psd_p);
    delete header;
}

psd::psd(const char* path) {
    
    header = new psd_header();
    
    const char* file_name_all  = strrchr(path, '/') + 1;
    const char* ext_name  = strrchr(file_name_all, '.');
    char file_name[256];
    strncpy(file_name, file_name_all, strlen(file_name_all) - strlen(ext_name));
    
    std::cout << file_name << std::endl;
    
    if ( (psd_p = fopen(path, "rb")) ) {
        header->nlayers = header->version = 0;
        header->layerdatapos = 0;
        
        fread(header->sig, 1, 4, psd_p);
        header->version = read_2byteU(psd_p);
        read_4byte(psd_p);read_2byte(psd_p); // reserved 6 byte
        header->channels = read_2byteU(psd_p);
        header->rows = read_4byte(psd_p);
        header->cols = read_4byte(psd_p);
        header->depth = read_2byteU(psd_p);
        header->mode = read_2byteU(psd_p);
        
        if (!feof(psd_p) && EQ_STR_C(header->sig, "8BPS")) {
            if (header->version == 1 || header->version == 2) {
                if (is_valid_header(header)) {
                    header->colormodepos = (psd_bytes_t)ftello(psd_p);
                    skipblock(psd_p, "color mode data");
                    
                    header->resourcepos = (psd_bytes_t)ftello(psd_p);
                    skipblock(psd_p, "image resources");
                    
                    if (!dolayermaskinfo(psd_p, header)) {
                        exit(1);
                    }
                    
                    header->layerdatapos = (psd_bytes_t)ftello(psd_p);
                }
            }
            
        }
        
    }
}

void psd::parselayers()
{
    int i;
    layer_data = (LayerInfo*)malloc(sizeof(LayerInfo) * header->nlayers);
    for(i = 0; i < header->nlayers; ++i){
        struct layer_info *li = &header->linfo[i];
        li->unicode_name = NULL;
        if (header->depth != 32)
            layer_data[i] = doimage(psd_p, li, li->name, header);
        
    }
}
