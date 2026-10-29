/* SPDX-License-Identifier: MIT
 * On-device allocation/import/map regression check for Android YV12 buffers.
 */
#include "drv.h"
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define CHECK(condition) do { if (!(condition)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); return 1; \
} } while (0)
#define LOAD(name) __typeof__(name) *p_##name = dlsym(library, #name); CHECK(p_##name)

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    void *library = dlopen("libminigbm_gralloc_gbm_mesa.so", RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        fprintf(stderr, "dlopen: %s\n", dlerror());
        return 1;
    }
    LOAD(drv_create); LOAD(drv_destroy); LOAD(drv_bo_create); LOAD(drv_bo_destroy);
    LOAD(drv_bo_get_num_planes); LOAD(drv_bo_get_plane_fd); LOAD(drv_bo_get_plane_stride);
    LOAD(drv_bo_get_plane_offset); LOAD(drv_bo_get_format_modifier);
    LOAD(drv_bo_import); LOAD(drv_bo_map); LOAD(drv_bo_unmap);

    int fd = open("/dev/dri/renderD128", O_RDWR | O_CLOEXEC);
    CHECK(fd >= 0);
    struct driver *allocator = p_drv_create(fd);
    struct driver *mapper = p_drv_create(fd);
    CHECK(allocator && mapper);
    /* Check varied pitches, including widths not divisible by 32/512. */
    const uint32_t widths[] = { 64, 384, 640, 720, 1280 };
    for (size_t i = 0; i < sizeof(widths) / sizeof(widths[0]); i++) {
        uint32_t width = widths[i], height = 240;
        uint64_t usage = BO_USE_TEXTURE | BO_USE_SW_READ_OFTEN | BO_USE_SW_WRITE_OFTEN;
        struct bo *bo = p_drv_bo_create(allocator, width, height, DRM_FORMAT_YVU420_ANDROID, usage);
        CHECK(bo);
        size_t planes = p_drv_bo_get_num_planes(bo);
        printf("YV12 %ux%u: %zu planes\n", width, height, planes);
        CHECK(planes == 3);
        struct drv_import_fd_data data = {
            .width = width, .height = height, .format = DRM_FORMAT_YVU420_ANDROID,
            .use_flags = usage, .format_modifier = p_drv_bo_get_format_modifier(bo),
        };
        for (size_t plane = 0; plane < 3; plane++) {
            data.fds[plane] = p_drv_bo_get_plane_fd(bo, plane);
            data.strides[plane] = p_drv_bo_get_plane_stride(bo, plane);
            data.offsets[plane] = p_drv_bo_get_plane_offset(bo, plane);
            CHECK(data.fds[plane] >= 0);
            printf("  plane %zu: stride=%u offset=%u\n", plane, data.strides[plane], data.offsets[plane]);
        }
        CHECK(data.strides[0] >= width && data.strides[0] % 32 == 0);
        CHECK(data.strides[1] == data.strides[0] / 2 && data.strides[2] == data.strides[1]);
        CHECK(data.offsets[1] == data.strides[0] * height);
        CHECK(data.offsets[2] == data.offsets[1] + data.strides[1] * height / 2);
        struct bo *imported = p_drv_bo_import(mapper, &data);
        CHECK(imported && p_drv_bo_get_num_planes(imported) == 3);
        struct rectangle rect = { .x = 0, .y = 0, .width = width, .height = height };
        struct mapping *mapping = NULL;
        unsigned char *pixels = p_drv_bo_map(imported, &rect, BO_MAP_READ_WRITE, &mapping, 0);
        CHECK(pixels && pixels != MAP_FAILED);
        size_t size = data.offsets[2] + data.strides[2] * height / 2;
        memset(pixels, 128, size);
        CHECK(p_drv_bo_unmap(imported, mapping) == 0);
        p_drv_bo_destroy(imported);
        p_drv_bo_destroy(bo);
        for (size_t plane = 0; plane < 3; plane++)
            close(data.fds[plane]);
    }
    /* RGB allocation remains on the untouched original backend. */
    struct bo *rgb = p_drv_bo_create(allocator, 128, 128, DRM_FORMAT_ABGR8888, BO_USE_TEXTURE);
    CHECK(rgb && p_drv_bo_get_num_planes(rgb) == 1);
    p_drv_bo_destroy(rgb);
    p_drv_destroy(mapper);
    p_drv_destroy(allocator);
    close(fd);
    puts("PASS: YV12 allocation/import/map and RGB allocation");
    return 0;
}
