//
//  psd_writer.h
//  KZPSDWriter
//
//  Created by uchiyama_Macmini on 2020/03/11.
//  Copyright © 2020年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_writer_h
#define psd_writer_h

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */
    
#include <stdlib.h>
#include <assert.h>
    
typedef _Bool psd_bool_t;
typedef uint8_t psd_uint8_t;
typedef int16_t psd_int16_t;
typedef uint16_t psd_uint16_t;
typedef int32_t psd_int32_t;
typedef uint32_t psd_uint32_t;
typedef int64_t psd_int64_t;
typedef uint64_t psd_uint64_t;
typedef float psd_float32_t;
typedef double psd_float64_t;
typedef size_t psd_rsize_t;
    
#ifndef PSD_DECL_INLINE
#define PSD_DECL_INLINE inline
#endif /* PSD_DECL_INLINE */
    
#ifndef PSD_DECL_API
#define PSD_DECL_API extern
#endif /* PSD_DECL_API */
    
#ifndef PSD_MAKE_TAG
#define PSD_MAKE_TAG(a, b, c, d) ((a) << 24 | (b) << 16 | (c) << 8 | (d))
#endif /* PSD_MAKE_TAG */

#define psd_has_error(cond) ((cond) != PSD_STATUS_SUCCESS)
#define psd_is_null(cond) ((cond) == PSD_NULL)
#define psd_is_not_null(cond) ((cond) != PSD_NULL)
#define psd_mark_unused(cond) ((void)(cond))
#define psd_string_equals(s1, s2) (psd_is_not_null((s1)) && psd_is_not_null((s2)) && strcmp((s1), (s2)) == 0)

#ifndef PSD_NULL
#define PSD_NULL NULL
#endif /* psd_null */

_Static_assert(sizeof(psd_uint8_t)  == 1, "size of psd_uint8_t must be 1");
_Static_assert(sizeof(psd_int16_t)  == 2, "size of psd_int16_t must be 2");
_Static_assert(sizeof(psd_uint16_t) == 2, "size of psd_uint16_t must be 2");
_Static_assert(sizeof(psd_int32_t)  == 4, "size of psd_int32_t must be 4");
_Static_assert(sizeof(psd_uint32_t) == 4, "size of psd_uint32_t must be 4");
_Static_assert(sizeof(psd_int64_t)  == 8, "size of psd_int64_t must be 8");
_Static_assert(sizeof(psd_uint64_t) == 8, "size of psd_uint64_t must be 8");

enum psd_status_t {
    PSD_STATUS_SUCCESS,
    PSD_STATUS_ERROR_NULL_BUFFER,
    PSD_STATUS_ERROR_NULL_DOCUMENT,
    PSD_STATUS_ERROR_NULL_HEADER,
    PSD_STATUS_ERROR_NULL_DESCRIPTOR,
    PSD_STATUS_ERROR_NULL_RESOURCE_SLICE,
    PSD_STATUS_ERROR_NULL_RESOURCE,
    PSD_STATUS_ERROR_NULL_TYPE_TOOL,
    PSD_STATUS_ERROR_NULL_BLEND_MODE,
    PSD_STATUS_ERROR_NULL_MASK,
    PSD_STATUS_ERROR_NULL_ANNOTATION,
    PSD_STATUS_ERROR_NULL_PATH_INFO,
    PSD_STATUS_ERROR_NULL_LAYER_CHANNEL,
    PSD_STATUS_ERROR_NULL_LAYER_INFO,
    PSD_STATUS_ERROR_NULL_LAYER,
    PSD_STATUS_ERROR_NULL_IMAGE,
    PSD_STATUS_ERROR_INVALID_HEADER_SIGNATURE = 100,
    PSD_STATUS_ERROR_INVALID_VERSION,
    PSD_STATUS_ERROR_INVALID_CHANNEL_RANGE,
    PSD_STATUS_ERROR_INVALID_SIZE_RANGE,
    PSD_STATUS_ERROR_INVALID_DEPTH_RANGE,
    PSD_STATUS_ERROR_INVALID_COLOR_MODE,
    PSD_STATUS_ERROR_INVALID_RESOURCE_SIGNATURE,
    PSD_STATUS_ERROR_INVALID_LAYER_INFO_SIGNATURE,
    PSD_STATUS_ERROR_UNSUPPORTED_IMAGE_COMPRESSION = 200,
    PSD_STATUS_ERROR_UNSUPPORTED_IMAGE_EXTRACTION,
    PSD_STATUS_ERROR_UNSUPPORTED_RESOURCE_SLICE_VERSION,
    PSD_STATUS_ERROR_UNSUPPORTED_RESOURCE_DESCRIPTOR_VERSION,
    PSD_STATUS_ERROR_SIZE_OVERFLOW = 300,
    PSD_STATUS_MAX_ENUM
};

enum psd_direction_t {
    PSD_DIRECTION_VERTICAL,
    PSD_DIRECTION_HORIZONTAL
};

enum psd_color_mode_t {
    PSD_COLOR_MODE_BITMAP,
    PSD_COLOR_MODE_GRAY_SCALE,
    PSD_COLOR_MODE_INDEXED,
    PSD_COLOR_MODE_RGB,
    PSD_COLOR_MODE_CMYK,
    PSD_COLOR_MODE_HSL,
    PSD_COLOR_MODE_HSB,
    PSD_COLOR_MODE_MULTICHANNEL,
    PSD_COLOR_MODE_DUOTONE,
    PSD_COLOR_MODE_LAB,
    PSD_COLOR_MODE_GRAY16,
    PSD_COLOR_MODE_RGB48,
    PSD_COLOR_MODE_LAB48,
    PSD_COLOR_MODE_CMYK64,
    PSD_COLOR_MODE_DEEP_MULTICHANNEL,
    PSD_COLOR_MODE_DUOTONE16,
    PSD_COLOR_MODE_MAX_ENUM
};

enum psd_resource_id_t {
    PSD_RESOURCE_ID_NULL,
    PSD_RESOURCE_ID_GUIDE = 1032,
    PSD_RESOURCE_ID_THUMBNAIL_PS4 = 1033,
    PSD_RESOURCE_ID_THUMBNAIL_PS5 = 1036,
    PSD_RESOURCE_ID_COLOR_SAMPLER_PS5 = 1038,
    PSD_RESOURCE_ID_ICC_PROFILE = 1039,
    PSD_RESOURCE_ID_ICC_UNTAGGED_PROFILE = 1041,
    PSD_RESOURCE_ID_SLICES = 1050,
    PSD_RESOURCE_ID_LAYER_COMP_DESC = 1065,
    PSD_RESOURCE_ID_COLOR_SAMPLER_CS3 = 1073,
    PSD_RESOURCE_ID_MEASUREMENT_SCALE_DESC = 1074,
    PSD_RESOURCE_ID_TIMELINE_DESC = 1075,
    PSD_RESOURCE_ID_SHEET_DISCLOSURE_DESC = 1076,
    PSD_RESOURCE_ID_ONION_SKIN_DESC = 1078,
    PSD_RESOURCE_ID_COUNT_DESC = 1080,
    PSD_RESOURCE_ID_PRINT_DESC = 1082,
    PSD_RESOURCE_ID_PRINT_STYLE_DESC = 1083,
    PSD_RESOURCE_ID_PATH_SELECTION_STATE_DESC = 1088,
    PSD_RESOURCE_ID_ORIGIN_PATH_DESC = 3000
};

enum psd_blend_mode_key_t {
    PSD_BLEND_MODE_NULL,
    PSD_BLEND_MODE_NORMAL        = PSD_MAKE_TAG('n', 'o', 'r', 'm'),
    PSD_BLEND_MODE_DARKEN        = PSD_MAKE_TAG('d', 'a', 'r', 'k'),
    PSD_BLEND_MODE_LIGHTEN       = PSD_MAKE_TAG('l', 'i', 't', 'e'),
    PSD_BLEND_MODE_HUE           = PSD_MAKE_TAG('h', 'u', 'e', ' '),
    PSD_BLEND_MODE_SATURATION    = PSD_MAKE_TAG('s', 'a', 't', ' '),
    PSD_BLEND_MODE_COLOR         = PSD_MAKE_TAG('c', 'o', 'l', ' '),
    PSD_BLEND_MODE_LUMINOSITY    = PSD_MAKE_TAG('l', 'u', 'm', ' '),
    PSD_BLEND_MODE_MULTIPLY      = PSD_MAKE_TAG('m', 'u', 'l', ' '),
    PSD_BLEND_MODE_SCREEN        = PSD_MAKE_TAG('s', 'c', 'r', 'n'),
    PSD_BLEND_MODE_DISSOLVE      = PSD_MAKE_TAG('d', 'i', 's', 's'),
    PSD_BLEND_MODE_OVERLAY       = PSD_MAKE_TAG('o', 'v', 'e', 'r'),
    PSD_BLEND_MODE_HARD_LIGHT    = PSD_MAKE_TAG('h', 'L', 'i', 't'),
    PSD_BLEND_MODE_SOFT_LIGHT    = PSD_MAKE_TAG('s', 'L', 'i', 't'),
    PSD_BLEND_MODE_DIFFERENCE    = PSD_MAKE_TAG('d', 'i', 'f', 'f'),
    PSD_BLEND_MODE_EXCLUSION     = PSD_MAKE_TAG('s', 'M', 'u', 'd'),
    PSD_BLEND_MODE_COLOR_DODGE   = PSD_MAKE_TAG('d', 'i', 'v', ' '),
    PSD_BLEND_MODE_COLOR_BURN    = PSD_MAKE_TAG('i', 'd', 'i', 'v'),
    PSD_BLEND_MODE_LINEAR_BURN   = PSD_MAKE_TAG('l', 'b', 'r', 'n'),
    PSD_BLEND_MODE_LINEAR_DODGE  = PSD_MAKE_TAG('l', 'd', 'd', 'g'),
    PSD_BLEND_MODE_VIVID_LIGHT   = PSD_MAKE_TAG('v', 'L', 'i', 't'),
    PSD_BLEND_MODE_LINEAR_LIGHT  = PSD_MAKE_TAG('l', 'L', 'i', 't'),
    PSD_BLEND_MODE_PIN_LIGHT     = PSD_MAKE_TAG('p', 'L', 'i', 't'),
    PSD_BLEND_MODE_HARD_MIX      = PSD_MAKE_TAG('h', 'M', 'i', 'x'),
    PSD_BLEND_MODE_PASSTHROUGH   = PSD_MAKE_TAG('p', 'a', 's', 's'),
    PSD_BLEND_MODE_DARKER_COLOR  = PSD_MAKE_TAG('d', 'k', 'C', 'l'),
    PSD_BLEND_MODE_LIGHTER_COLOR = PSD_MAKE_TAG('l', 'g', 'C', 'l'),
    PSD_BLEND_MODE_SUBTRACT      = PSD_MAKE_TAG('f', 's', 'u', 'b'),
    PSD_BLEND_MODE_DIVIDE        = PSD_MAKE_TAG('f', 'd', 'i', 'v')
};

enum psd_layer_info_key_t {
    PSD_LAYER_INFO_INVALID,
    PSD_LAYER_INFO_ANIMATION_EFFECTS           = PSD_MAKE_TAG('a', 'n', 'F', 'X'),
    PSD_LAYER_INFO_ANNOTATIONS                 = PSD_MAKE_TAG('A', 'n', 'n', 'o'),
    PSD_LAYER_INFO_BLACK_AND_WHITE             = PSD_MAKE_TAG('b', 'l', 'w', 'h'),
    PSD_LAYER_INFO_BLEND_CLIPPING_ELEMENTS     = PSD_MAKE_TAG('c', 'l', 'b', 'l'),
    PSD_LAYER_INFO_BLEND_INTERIOR_ELEMENTS     = PSD_MAKE_TAG('i', 'n', 'f', 'x'),
    PSD_LAYER_INFO_BRIGHTNESS_AND_CONTRAST     = PSD_MAKE_TAG('b', 'r', 'i', 't'),
    PSD_LAYER_INFO_CHANNEL_BLEND_RESTRICTION   = PSD_MAKE_TAG('b', 'r', 's', 't'),
    PSD_LAYER_INFO_CHANNEL_MIXER               = PSD_MAKE_TAG('m', 'i', 'x', 'r'),
    PSD_LAYER_INFO_COLOR_LOOKUP                = PSD_MAKE_TAG('c', 'l', 'r', 'L'),
    PSD_LAYER_INFO_COTENT_GENERATOR_EXTRA_DATA = PSD_MAKE_TAG('C', 'g', 'E', 'd'),
    PSD_LAYER_INFO_EFFECT_LAYER                = PSD_MAKE_TAG('l', 'r', 'F', 'X'),
    PSD_LAYER_INFO_EXPOSURE                    = PSD_MAKE_TAG('e', 'x', 'p', 'A'),
    PSD_LAYER_INFO_FILL_OPACITY                = PSD_MAKE_TAG('i', 'O', 'p', 'a'),
    PSD_LAYER_INFO_FILTER_EFFECTS              = PSD_MAKE_TAG('F', 'X', 'i', 'd'),
    PSD_LAYER_INFO_FILTER_EFFECTS2             = PSD_MAKE_TAG('F', 'E', 'i', 'd'),
    PSD_LAYER_INFO_FILTER_MASK                 = PSD_MAKE_TAG('F', 'M', 's', 'k'),
    PSD_LAYER_INFO_FOREIGN_EFFECT_ID           = PSD_MAKE_TAG('f', 'f', 'x', 'i'),
    PSD_LAYER_INFO_GRADIENT                    = PSD_MAKE_TAG('g', 'r', 'd', 'm'),
    PSD_LAYER_INFO_GRADIENT_FILL               = PSD_MAKE_TAG('G', 'd', 'F', 'l'),
    PSD_LAYER_INFO_KNOCKOUT                    = PSD_MAKE_TAG('k', 'n', 'k', 'o'),
    PSD_LAYER_INFO_LAYER_ID                    = PSD_MAKE_TAG('l', 'y', 'i', 'd'),
    PSD_LAYER_INFO_LAYER_MASK_AS_GLOBAL_MASK   = PSD_MAKE_TAG('l', 'm', 'g', 'm'),
    PSD_LAYER_INFO_LAYER_NAME_SOURCE           = PSD_MAKE_TAG('l', 'n', 's', 'r'),
    PSD_LAYER_INFO_LAYER_SECTION_DIVIDER       = PSD_MAKE_TAG('l', 's', 'c', 't'),
    PSD_LAYER_INFO_LAYER_VERSION               = PSD_MAKE_TAG('l', 'y', 'v', 'r'),
    PSD_LAYER_INFO_LEGACY_TYPE_TOOL            = PSD_MAKE_TAG('t', 'y', 'S', 'h'),
    PSD_LAYER_INFO_LOCKED                      = PSD_MAKE_TAG('l', 's', 'p', 'f'),
    PSD_LAYER_INFO_LINKED_LAYER                = PSD_MAKE_TAG('l', 'n', 'k', 'D'),
    PSD_LAYER_INFO_LINKED_LAYER2               = PSD_MAKE_TAG('l', 'n', 'k', '1'),
    PSD_LAYER_INFO_LINKED_LAYER3               = PSD_MAKE_TAG('l', 'n', 'k', '2'),
    PSD_LAYER_INFO_METADATA_SETTING            = PSD_MAKE_TAG('s', 'h', 'm', 'd'),
    PSD_LAYER_INFO_NESTED_LAYER_DIVIDER        = PSD_MAKE_TAG('l', 's', 'd', 'k'),
    PSD_LAYER_INFO_OBJECT_EFFECTS              = PSD_MAKE_TAG('l', 'f', 'x', '2'),
    PSD_LAYER_INFO_PATTERN                     = PSD_MAKE_TAG('P', 'a', 't', 't'),
    PSD_LAYER_INFO_PATTERN2                    = PSD_MAKE_TAG('P', 'a', 't', '2'),
    PSD_LAYER_INFO_PATTERN3                    = PSD_MAKE_TAG('P', 'a', 't', '3'),
    PSD_LAYER_INFO_PATTERN_DATA                = PSD_MAKE_TAG('s', 'p', 'h', 'a'),
    PSD_LAYER_INFO_PATTERN_FILL                = PSD_MAKE_TAG('P', 't', 'F', 'l'),
    PSD_LAYER_INFO_PHOTO_FILTER                = PSD_MAKE_TAG('p', 'h', 'f', 'l'),
    PSD_LAYER_INFO_PLACED_LAYER                = PSD_MAKE_TAG('S', 'o', 'L', 'd'),
    PSD_LAYER_INFO_PLACED_LAYER2               = PSD_MAKE_TAG('p', 'l', 'L', 'd'),
    PSD_LAYER_INFO_REFERENCE_POINT             = PSD_MAKE_TAG('f', 'x', 'r', 'p'),
    PSD_LAYER_INFO_SAVING_MERGED_TRANSPARENCY  = PSD_MAKE_TAG('M', 't', 'r', 'n'),
    PSD_LAYER_INFO_SAVING_MERGED_TRANSPARENCY2 = PSD_MAKE_TAG('M', 't', '1', '6'),
    PSD_LAYER_INFO_SAVING_MERGED_TRANSPARENCY3 = PSD_MAKE_TAG('M', 't', '3', '2'),
    PSD_LAYER_INFO_SHEET_COLOR                 = PSD_MAKE_TAG('l', 'c', 'l', 'r'),
    PSD_LAYER_INFO_SOLID_COLOR                 = PSD_MAKE_TAG('S', 'o', 'C', 'o'),
    PSD_LAYER_INFO_TEXT_ENGINE_DATA            = PSD_MAKE_TAG('T', 'x', 't', '2'),
    PSD_LAYER_INFO_TYPE_TOOL                   = PSD_MAKE_TAG('T', 'y', 'S', 'h'),
    PSD_LAYER_INFO_TRANSPARENCY_SHAPE_LAYER    = PSD_MAKE_TAG('t', 's', 'l', 'y'),
    PSD_LAYER_INFO_UNICODE_NAME                = PSD_MAKE_TAG('l', 'u', 'n', 'i'),
    PSD_LAYER_INFO_UNICODE_PATH_NAME           = PSD_MAKE_TAG('p', 't', 'h', 's'),
    PSD_LAYER_INFO_USER_MASK                   = PSD_MAKE_TAG('L', 'M', 's', 'k'),
    PSD_LAYER_INFO_USING_ALIGNED_RENDERING     = PSD_MAKE_TAG('s', 'n', '2', 'P'),
    PSD_LAYER_INFO_VECTOR_MASK                 = PSD_MAKE_TAG('v', 'm', 's', 'k'),
    PSD_LAYER_INFO_VECTOR_MASK2                = PSD_MAKE_TAG('v', 's', 'm', 's'),
    PSD_LAYER_INFO_VECTOR_MASK_AS_GLOBAL_MASK  = PSD_MAKE_TAG('v', 'm', 'g', 'm'),
    PSD_LAYER_INFO_VECTOR_ORIGINATION          = PSD_MAKE_TAG('v', 'o', 'g', 'k'),
    PSD_LAYER_INFO_VECTOR_STROKE               = PSD_MAKE_TAG('v', 's', 't', 'k'),
    PSD_LAYER_INFO_VECTOR_STROKE_CONTENT       = PSD_MAKE_TAG('v', 's', 'c', 'g'),
    PSD_LAYER_INFO_VIBRANCE                    = PSD_MAKE_TAG('v', 'i', 'b', 'A')
};

enum psd_layer_order_t {
    PSD_LAYER_ORDER_DESCEND,
    PSD_LAYER_ORDER_ASCEND
};

enum psd_descriptor_key_t {
    PSD_DESCRIPTOR_INVALID,
    PSD_DESCRIPTOR_BOOL          = PSD_MAKE_TAG('b', 'o', 'o', 'l'),
    PSD_DESCRIPTOR_CLASS         = PSD_MAKE_TAG('t', 'y', 'p', 'e'),
    PSD_DESCRIPTOR_GLOBAL_CLASS  = PSD_MAKE_TAG('G', 'l', 'b', 'C'),
    PSD_DESCRIPTOR_OBJECT        = PSD_MAKE_TAG('O', 'b', 'j', 'c'),
    PSD_DESCRIPTOR_GLOBAL_OBJECT = PSD_MAKE_TAG('G', 'l', 'b', 'O'),
    PSD_DESCRIPTOR_DOUBLE        = PSD_MAKE_TAG('d', 'o', 'u', 'b'),
    PSD_DESCRIPTOR_ENUM          = PSD_MAKE_TAG('e', 'n', 'u', 'm'),
    PSD_DESCRIPTOR_ALIAS         = PSD_MAKE_TAG('a', 'l', 'i', 's'),
    PSD_DESCRIPTOR_FILEPATH      = PSD_MAKE_TAG('P', 't', 'h', ' '),
    PSD_DESCRIPTOR_INT           = PSD_MAKE_TAG('l', 'o', 'n', 'g'),
    PSD_DESCRIPTOR_LARGE_INT     = PSD_MAKE_TAG('c', 'o', 'm', 'p'),
    PSD_DESCRIPTOR_LIST          = PSD_MAKE_TAG('V', 'l', 'L', 's'),
    PSD_DESCRIPTOR_OBJECT_ARRAY  = PSD_MAKE_TAG('O', 'b', 'A', 'r'),
    PSD_DESCRIPTOR_RAW           = PSD_MAKE_TAG('t', 'd', 't', 'a'),
    PSD_DESCRIPTOR_REFERENCE     = PSD_MAKE_TAG('o', 'b', 'j', ' '),
    PSD_DESCRIPTOR_UNICODE_TEXT  = PSD_MAKE_TAG('T', 'E', 'X', 'T'),
    PSD_DESCRIPTOR_UNIT_DOUBLE   = PSD_MAKE_TAG('U', 'n', 't', 'F'),
    PSD_DESCRIPTOR_UNIT_FLOAT    = PSD_MAKE_TAG('U', 'n', 'F', 'l'),
    /* only in reference */
    PSD_DESCRIPTOR_PROPERTY      = PSD_MAKE_TAG('p', 'r', 'o', 'p'),
    PSD_DESCRIPTOR_CLASS_REF     = PSD_MAKE_TAG('C', 'l', 's', 's'),
    PSD_DESCRIPTOR_ENUM_REF      = PSD_MAKE_TAG('E', 'n', 'm', 'r'),
    PSD_DESCRIPTOR_IDENTIFIER    = PSD_MAKE_TAG('I', 'd', 'n', 't'),
    PSD_DESCRIPTOR_INDEX         = PSD_MAKE_TAG('i', 'n', 'd', 'x'),
    PSD_DESCRIPTOR_NAME          = PSD_MAKE_TAG('n', 'a', 'm', 'e'),
    PSD_DESCRIPTOR_OFFSET        = PSD_MAKE_TAG('r', 'e', 'l', 'e')
};
    
enum psd_unit_key_t {
    PSD_UNIT_INVALID,
    PSD_UNIT_ANGLE       = PSD_MAKE_TAG('#', 'A', 'n', 'g'),
    PSD_UNIT_DENSITY     = PSD_MAKE_TAG('#', 'R', 's', 'l'),
    PSD_UNIT_DISTANCE    = PSD_MAKE_TAG('#', 'R', 'l', 't'),
    PSD_UNIT_NONE        = PSD_MAKE_TAG('#', 'N', 'n', 'e'),
    PSD_UNIT_PERCENT     = PSD_MAKE_TAG('#', 'P', 'r', 'c'),
    PSD_UNIT_PIXEL       = PSD_MAKE_TAG('#', 'P', 'x', 'l'),
    PSD_UNIT_MILLIMETERS = PSD_MAKE_TAG('#', 'M', 'l', 'm'),
    PSD_UNIT_POINTS      = PSD_MAKE_TAG('#', 'P', 'n', 't')
};

enum psd_image_compression_t {
    PSD_IMAGE_COMPRESSION_RAW,
    PSD_IMAGE_COMPRESSION_RLE,
    PSD_IMAGE_COMPRESSION_ZIP,
    PSD_IMAGE_COMPRESSION_ZIP_PREDICTION,
    PSD_IMAGE_COMPRESSION_MAX_ENUM
};
    
typedef enum psd_status_t psd_status_t;
typedef enum psd_direction_t psd_direction_t;
typedef enum psd_resource_id_t psd_resource_id_t;
typedef enum psd_blend_mode_key_t psd_blend_mode_key_t;
typedef enum psd_color_mode_t psd_color_mode_t;
typedef enum psd_layer_info_key_t psd_layer_info_key_t;
typedef enum psd_layer_order_t psd_layer_order_t;
typedef enum psd_descriptor_key_t psd_descriptor_key_t;
typedef enum psd_unit_key_t psd_unit_key_t;
typedef enum psd_image_compression_t psd_image_compression_t;

typedef struct psd_header_t psd_header_t;
typedef struct psd_size_t psd_size_t;
    
struct psd_size_t {
    psd_uint32_t rows;
    psd_uint32_t cols;
};
    
struct psd_header_t {
    psd_uint32_t signature;
    psd_uint32_t version;
    psd_uint32_t num_channels;
    psd_size_t size;
    psd_uint32_t depths;
    psd_color_mode_t color_mode;
    psd_uint8_t *color_mode_data;
};


struct psd_make_info_t {
    psd_bool_t has_alpha;
    psd_uint32_t width;
    psd_uint32_t height;
    float resolusion;
};
psd_header_t* psdHeaderCreate(psd_uint32_t width, psd_uint32_t height, psd_bool_t hasAlpha);
void psdHeaderDestroy(psd_header_t *header);

//PSD_DECL_API psd_document_t *psdCreateDocument(psd_uint32_t width, psd_uint32_t height, float resolution);
//PSD_DECL_API psd_layer_t *psdMakeLayer(const void* img, size_t length, const char *name, float opacity);

#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif /* psd_writer_h */
