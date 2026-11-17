#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gl_posix.h"

typedef struct {
    const char *name;
    uint64_t original_hash;
    int width, height, scale;
    GLenum format;
} HdTexture;

static const HdTexture k_textures[] = {
    /* Embedded DDS base levels in Chapter 1's stage and enemy banks. */
    {"stage01_a00-33", UINT64_C(0x80dbb159eb446194), 128, 256, 4, GL_COMPRESSED_RGBA_S3TC_DXT1_EXT},
    {"stage01_a00-50", UINT64_C(0xc4a9657e0a7e112c), 256, 256, 4, GL_COMPRESSED_RGBA_S3TC_DXT1_EXT},
    {"stage01_a00-57", UINT64_C(0x42a23cdfe45e0d61), 256, 256, 4, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT},
    {"stage01_a00-58", UINT64_C(0x3797ed16e1572498), 256, 256, 4, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT},
    {"stage01_a00-69", UINT64_C(0x717f01735c5caeef), 128, 128, 4, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT},
    {"stage01_a00-71", UINT64_C(0x90976b415216bedf), 128, 128, 4, GL_COMPRESSED_RGBA_S3TC_DXT1_EXT},
    {"stage01_a00-79", UINT64_C(0xee1e8eb7abc9f693), 512, 512, 2, GL_COMPRESSED_RGBA_S3TC_DXT1_EXT},
    {"zn04a-4", UINT64_C(0xa1f5b5746b44ab28), 1024, 1024, 2, GL_COMPRESSED_RGBA_S3TC_DXT1_EXT},
    {"zn04a-13", UINT64_C(0x8fcb2da4188a667c), 1024, 1024, 2, GL_COMPRESSED_RGBA_S3TC_DXT1_EXT},
};

static const char *g_pack_path;
static struct {
    const HdTexture *texture;
    GLint gl_name;
    int expected_level;
} g_upload;

static int level_bytes(int width, int height, GLenum format)
{
    int block_bytes = format == GL_COMPRESSED_RGBA_S3TC_DXT1_EXT ? 8 : 16;
    return ((width + 3) / 4) * ((height + 3) / 4) * block_bytes;
}

static void next_mip(int *width, int *height)
{
    if (*width > 1) *width /= 2;
    if (*height > 1) *height /= 2;
}

static const HdTexture *find_hd_texture(int width, int height, GLenum format, const void *data, int bytes)
{
    uint64_t hash = 0;
    int hashed = 0;
    for (unsigned i = 0; i < sizeof k_textures / sizeof *k_textures; ++i) {
        const HdTexture *texture = &k_textures[i];
        if (width != texture->width || height != texture->height || format != texture->format ||
            bytes != level_bytes(width, height, format)) continue;
        if (!hashed) {
            const unsigned char *pixels = data;
            hash = UINT64_C(14695981039346656037);
            for (int pos = 0; pos < bytes; ++pos)
                hash = (hash ^ pixels[pos]) * UINT64_C(1099511628211);
            hashed = 1;
        }
        if (hash == texture->original_hash) return texture;
    }
    return NULL;
}

static int upload_hd_texture(const HdTexture *texture)
{
    const int width = texture->width * texture->scale;
    const int height = texture->height * texture->scale;
    GLint max_dimension = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max_dimension);
    if (width > max_dimension || height > max_dimension) return 0;

    char path[1024];
    int len = snprintf(path, sizeof path, "%s/%s.bc", g_pack_path, texture->name);
    if (len < 0 || len >= (int)sizeof path) return 0;

    size_t bytes = 0;
    int w = width, h = height;
    for (;;) {
        bytes += (size_t)level_bytes(w, h, texture->format);
        if (w == 1 && h == 1) break;
        next_mip(&w, &h);
    }

    FILE *file = fopen(path, "rb");
    if (!file) {
        fprintf(stderr, "[hd-textures] Could not open %s\n", path);
        return 0;
    }
    unsigned char *data = malloc(bytes);
    int valid = data && fread(data, 1, bytes, file) == bytes && fgetc(file) == EOF && !ferror(file);
    fclose(file);
    if (!valid) {
        fprintf(stderr, "[hd-textures] Could not read %s\n", path);
        free(data);
        return 0;
    }

    size_t offset = 0;
    w = width;
    h = height;
    for (int level = 0; offset < bytes; ++level) {
        int size = level_bytes(w, h, texture->format);
        glCompressedTexImage2D(GL_TEXTURE_2D, level, texture->format, w, h, 0, size, data + offset);
        offset += (size_t)size;
        next_mip(&w, &h);
    }
    free(data);
    fprintf(stderr, "[hd-textures] %s %dx%d -> %dx%d\n", texture->name,
            texture->width, texture->height, width, height);
    return 1;
}

static int has_replacement_mip(int level, GLenum format, int width, int height, int bytes)
{
    const HdTexture *texture = g_upload.texture;
    if (!texture || level != g_upload.expected_level || format != texture->format)
        return 0;
    int w = texture->width, h = texture->height;
    for (int i = 0; i < level; ++i) next_mip(&w, &h);
    if (w != width || h != height || bytes != level_bytes(w, h, format)) return 0;

    GLint bound = 0;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, &bound);
    if (bound != g_upload.gl_name) return 0;
    ++g_upload.expected_level;
    return 1;
}

static void texture_image(CPU *c)
{
    GLenum target = A32(0), format = A32(2);
    int level = AI32(1), width = AI32(3), height = AI32(4), border = AI32(5), bytes = AI32(6);
    const void *data = gl_ptr_or_offset(GL_PIXEL_UNPACK_BUFFER, A32(7));
    gl_trace("glCompressedTexImage2D");
    if (target == GL_TEXTURE_2D && border == 0) {
        if (level == 0) {
            g_upload.texture = NULL;
            GLint pbo = 0;
            glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING, &pbo);
            if (data && !pbo) {
                const HdTexture *texture = find_hd_texture(width, height, format, data, bytes);
                if (texture && upload_hd_texture(texture)) {
                    glGetIntegerv(GL_TEXTURE_BINDING_2D, &g_upload.gl_name);
                    g_upload.texture = texture;
                    g_upload.expected_level = 1;
                    gl_check("HD glCompressedTexImage2D");
                    return;
                }
            }
        } else if (has_replacement_mip(level, format, width, height, bytes)) {
            return;
        } else {
            /* The guest uploads the levels of a bank texture in sequence. */
            g_upload.texture = NULL;
        }
    }
    glCompressedTexImage2D(target, level, format, width, height, border, bytes, data);
    gl_check("glCompressedTexImage2D");
}

void hotd4_install_hd_textures(void)
{
    g_pack_path = getenv("HOTD4_HD_TEXTURE_DIR");
    if (!g_pack_path || !*g_pack_path) return;
    gl_bind_named("glCompressedTexImage2D", texture_image);
    gl_bind_named("glCompressedTexImage2DARB", texture_image);
}
