#ifndef WAWONA_CAIRO_SHIM_H
#define WAWONA_CAIRO_SHIM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Basic Cairo Types */
typedef struct _cairo cairo_t;
typedef struct _cairo_surface cairo_surface_t;
typedef struct _cairo_pattern cairo_pattern_t;
typedef struct _cairo_device cairo_device_t;
typedef struct _cairo_scaled_font cairo_scaled_font_t;
typedef struct _cairo_font_options cairo_font_options_t;

typedef struct {
  double xx, yx, xy, yy, x0, y0;
} cairo_matrix_t;

typedef struct {
  unsigned long index;
  double x, y;
} cairo_glyph_t;

typedef struct {
  double ascent;
  double descent;
  double height;
  double max_x_advance;
  double max_y_advance;
} cairo_font_extents_t;

typedef struct {
  double x_bearing;
  double y_bearing;
  double width;
  double height;
  double x_advance;
  double y_advance;
} cairo_text_extents_t;

typedef struct {
  int x, y, width, height;
} cairo_rectangle_int_t;

typedef enum {
  CAIRO_STATUS_SUCCESS = 0,
  CAIRO_STATUS_NO_MEMORY,
  CAIRO_STATUS_INVALID_RESTORE,
  CAIRO_STATUS_INVALID_POP_GROUP,
  CAIRO_STATUS_NO_CURRENT_POINT,
  CAIRO_STATUS_INVALID_MATRIX,
  CAIRO_STATUS_INVALID_STATUS,
  CAIRO_STATUS_NULL_POINTER,
  CAIRO_STATUS_INVALID_STRING,
  CAIRO_STATUS_INVALID_PATH_DATA,
  CAIRO_STATUS_READ_ERROR,
  CAIRO_STATUS_WRITE_ERROR,
  CAIRO_STATUS_SURFACE_FINISHED,
  CAIRO_STATUS_SURFACE_TYPE_MISMATCH,
  CAIRO_STATUS_PATTERN_TYPE_MISMATCH,
  CAIRO_STATUS_INVALID_CONTENT,
  CAIRO_STATUS_INVALID_FORMAT,
  CAIRO_STATUS_INVALID_VISUAL,
  CAIRO_STATUS_FILE_NOT_FOUND,
  CAIRO_STATUS_INVALID_DASH,
  CAIRO_STATUS_INVALID_DSC_COMMENT,
  CAIRO_STATUS_INVALID_INDEX,
  CAIRO_STATUS_CLIP_NOT_REPRESENTABLE,
  CAIRO_STATUS_TEMP_FILE_ERROR,
  CAIRO_STATUS_INVALID_STRIDE,
  CAIRO_STATUS_FONT_TYPE_MISMATCH,
  CAIRO_STATUS_USER_FONT_IMMUTABLE,
  CAIRO_STATUS_USER_FONT_ERROR,
  CAIRO_STATUS_NEGATIVE_COUNT,
  CAIRO_STATUS_INVALID_CLUSTERS,
  CAIRO_STATUS_INVALID_SLANT,
  CAIRO_STATUS_INVALID_WEIGHT,
  CAIRO_STATUS_INVALID_SIZE,
  CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED,
  CAIRO_STATUS_DEVICE_TYPE_MISMATCH,
  CAIRO_STATUS_DEVICE_ERROR,
  CAIRO_STATUS_INVALID_MESH_CONSTRUCTION,
  CAIRO_STATUS_DEVICE_FINISHED,
  CAIRO_STATUS_JBIG2_GLOBAL_MISSING
} cairo_status_t;

typedef enum {
  CAIRO_FORMAT_INVALID = -1,
  CAIRO_FORMAT_ARGB32 = 0,
  CAIRO_FORMAT_RGB24 = 1,
  CAIRO_FORMAT_A8 = 2,
  CAIRO_FORMAT_A1 = 3,
  CAIRO_FORMAT_RGB16_565 = 4,
  CAIRO_FORMAT_RGB30 = 5
} cairo_format_t;

typedef enum {
  CAIRO_OPERATOR_CLEAR,
  CAIRO_OPERATOR_SOURCE,
  CAIRO_OPERATOR_OVER,
  CAIRO_OPERATOR_IN,
  CAIRO_OPERATOR_OUT,
  CAIRO_OPERATOR_ATOP,
  CAIRO_OPERATOR_DEST,
  CAIRO_OPERATOR_DEST_OVER,
  CAIRO_OPERATOR_DEST_IN,
  CAIRO_OPERATOR_DEST_OUT,
  CAIRO_OPERATOR_DEST_ATOP,
  CAIRO_OPERATOR_XOR,
  CAIRO_OPERATOR_ADD,
  CAIRO_OPERATOR_SATURATE
} cairo_operator_t;

typedef enum {
  CAIRO_ANTIALIAS_DEFAULT,
  CAIRO_ANTIALIAS_NONE,
  CAIRO_ANTIALIAS_GRAY,
  CAIRO_ANTIALIAS_SUBPIXEL,
  CAIRO_ANTIALIAS_FAST,
  CAIRO_ANTIALIAS_GOOD,
  CAIRO_ANTIALIAS_BEST
} cairo_antialias_t;

typedef enum {
  CAIRO_FILL_RULE_WINDING,
  CAIRO_FILL_RULE_EVEN_ODD
} cairo_fill_rule_t;

typedef enum {
  CAIRO_LINE_CAP_BUTT,
  CAIRO_LINE_CAP_ROUND,
  CAIRO_LINE_CAP_SQUARE
} cairo_line_cap_t;

typedef enum {
  CAIRO_LINE_JOIN_MITER,
  CAIRO_LINE_JOIN_ROUND,
  CAIRO_LINE_JOIN_BEVEL
} cairo_line_join_t;

typedef enum {
  CAIRO_FONT_SLANT_NORMAL,
  CAIRO_FONT_SLANT_ITALIC,
  CAIRO_FONT_SLANT_OBLIQUE
} cairo_font_slant_t;

typedef enum {
  CAIRO_FONT_WEIGHT_NORMAL,
  CAIRO_FONT_WEIGHT_BOLD
} cairo_font_weight_t;

typedef enum {
  CAIRO_SUBPIXEL_ORDER_DEFAULT,
  CAIRO_SUBPIXEL_ORDER_RGB,
  CAIRO_SUBPIXEL_ORDER_BGR,
  CAIRO_SUBPIXEL_ORDER_VRGB,
  CAIRO_SUBPIXEL_ORDER_VBGR
} cairo_subpixel_order_t;

typedef enum {
  CAIRO_HINT_STYLE_DEFAULT,
  CAIRO_HINT_STYLE_NONE,
  CAIRO_HINT_STYLE_SLIGHT,
  CAIRO_HINT_STYLE_MEDIUM,
  CAIRO_HINT_STYLE_FULL
} cairo_hint_style_t;

typedef enum {
  CAIRO_HINT_METRICS_DEFAULT,
  CAIRO_HINT_METRICS_OFF,
  CAIRO_HINT_METRICS_ON
} cairo_hint_metrics_t;

typedef enum {
  CAIRO_CONTENT_COLOR = 0x1000,
  CAIRO_CONTENT_ALPHA = 0x2000,
  CAIRO_CONTENT_COLOR_ALPHA = 0x3000
} cairo_content_t;

/* Surface Functions */
cairo_surface_t *cairo_image_surface_create(cairo_format_t format, int width,
                                            int height);
cairo_surface_t *cairo_image_surface_create_for_data(unsigned char *data,
                                                     cairo_format_t format,
                                                     int width, int height,
                                                     int stride);
void cairo_surface_destroy(cairo_surface_t *surface);
void cairo_surface_reference(cairo_surface_t *surface);
cairo_status_t cairo_surface_status(cairo_surface_t *surface);
void cairo_surface_flush(cairo_surface_t *surface);
void cairo_surface_mark_dirty(cairo_surface_t *surface);
unsigned char *cairo_image_surface_get_data(cairo_surface_t *surface);
int cairo_image_surface_get_stride(cairo_surface_t *surface);
int cairo_image_surface_get_width(cairo_surface_t *surface);
int cairo_image_surface_get_height(cairo_surface_t *surface);
cairo_format_t cairo_image_surface_get_format(cairo_surface_t *surface);
cairo_device_t *cairo_surface_get_device(cairo_surface_t *surface);
cairo_content_t cairo_surface_get_content(cairo_surface_t *surface);

/* Context Functions */
cairo_t *cairo_create(cairo_surface_t *target);
void cairo_destroy(cairo_t *cr);
cairo_status_t cairo_status(cairo_t *cr);
void cairo_save(cairo_t *cr);
void cairo_restore(cairo_t *cr);

/* Drawing Functions */
void cairo_set_source_rgb(cairo_t *cr, double red, double green, double blue);
void cairo_set_source_rgba(cairo_t *cr, double red, double green, double blue,
                           double alpha);
void cairo_set_source_surface(cairo_t *cr, cairo_surface_t *surface, double x,
                              double y);
void cairo_set_operator(cairo_t *cr, cairo_operator_t op);
void cairo_set_line_width(cairo_t *cr, double width);

void cairo_rectangle(cairo_t *cr, double x, double y, double width,
                     double height);
void cairo_fill(cairo_t *cr);
void cairo_fill_preserve(cairo_t *cr);
void cairo_stroke(cairo_t *cr);
void cairo_stroke_preserve(cairo_t *cr);
void cairo_paint(cairo_t *cr);
void cairo_clip(cairo_t *cr);
void cairo_reset_clip(cairo_t *cr);

/* Path Functions */
void cairo_move_to(cairo_t *cr, double x, double y);
void cairo_line_to(cairo_t *cr, double x, double y);
void cairo_rel_line_to(cairo_t *cr, double dx, double dy);
void cairo_close_path(cairo_t *cr);
void cairo_new_path(cairo_t *cr);
void cairo_new_sub_path(cairo_t *cr);

/* Transformation Functions */
void cairo_translate(cairo_t *cr, double tx, double ty);
void cairo_scale(cairo_t *cr, double sx, double sy);
void cairo_rotate(cairo_t *cr, double angle);
void cairo_transform(cairo_t *cr, const cairo_matrix_t *matrix);
void cairo_set_matrix(cairo_t *cr, const cairo_matrix_t *matrix);
void cairo_get_matrix(cairo_t *cr, cairo_matrix_t *matrix);
void cairo_identity_matrix(cairo_t *cr);

/* Text Functions */
void cairo_select_font_face(cairo_t *cr, const char *family,
                            cairo_font_slant_t slant,
                            cairo_font_weight_t weight);
void cairo_set_font_size(cairo_t *cr, double size);
void cairo_show_text(cairo_t *cr, const char *utf8);
void cairo_show_glyphs(cairo_t *cr, const cairo_glyph_t *glyphs,
                       int num_glyphs);
void cairo_font_extents(cairo_t *cr, cairo_font_extents_t *extents);
void cairo_text_extents(cairo_t *cr, const char *utf8,
                        cairo_text_extents_t *extents);

/* Pango Shim types */
typedef struct _PangoLayout PangoLayout;
typedef struct _PangoContext PangoContext;
typedef struct _PangoFontDescription PangoFontDescription;
typedef struct _PangoFontMap PangoFontMap;

/* Pango Functions */
PangoLayout *pango_cairo_create_layout(cairo_t *cr);
void pango_layout_set_text(PangoLayout *layout, const char *text, int length);
void pango_layout_get_pixel_size(PangoLayout *layout, int *width, int *height);
void pango_cairo_show_layout(cairo_t *cr, PangoLayout *layout);
void pango_layout_set_font_description(PangoLayout *layout,
                                       const PangoFontDescription *desc);
void g_object_unref(void *object);

PangoFontDescription *pango_font_description_new(void);
PangoFontDescription *pango_font_description_from_string(const char *str);
void pango_font_description_set_family(PangoFontDescription *desc,
                                       const char *family);
void pango_font_description_set_size(PangoFontDescription *desc, int size);
void pango_font_description_free(PangoFontDescription *desc);

#ifdef __cplusplus
}
#endif

#endif /* WAWONA_CAIRO_SHIM_H */
