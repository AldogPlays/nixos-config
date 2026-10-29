/* SPDX-License-Identifier: MIT
 * Restore YV12's three-plane description around Waydroid minigbm e5a7769.
 * The original backend still owns allocation, mapping and destruction. Its
 * private C++ objects are never inspected or modified by this adapter.
 */
#include "drv_priv.h"
#include "drv_helpers.h"
#include <android/log.h>
#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <string.h>

static const struct backend *original;
static struct backend corrected;
static pthread_once_t once = PTHREAD_ONCE_INIT;

static void copy_handles(struct bo *bo)
{
    for (size_t plane = 1; plane < 3; plane++)
        bo->handles[plane] = bo->handles[0];
}

static int create_yv12(struct bo *bo, uint32_t width, uint32_t height,
                       uint32_t format, uint64_t flags)
{
    int result = original->bo_create(bo, width, height, format, flags);
    if (result || format != DRM_FORMAT_YVU420_ANDROID)
        return result;

    uint32_t stride = bo->meta.strides[0];
    size_t allocated = bo->meta.total_size;
    /* The shipped allocator backs YV12 with a linear GR88 allocation. Its
     * byte pitch is the Y stride; chroma occupies the remaining half height.
     * Reject incompatible geometry rather than describing out-of-bounds data.
     */
    if (stride < width || stride % 32 || height % 2 ||
        (uint64_t)stride * height * 3 / 2 > allocated) {
        original->bo_destroy(bo);
        return -EINVAL;
    }
    drv_bo_from_format(bo, stride, height, format);
    bo->meta.num_planes = 3;
    copy_handles(bo);
    return 0;
}

static int import_yv12(struct bo *bo, struct drv_import_fd_data *data)
{
    if (data->format == DRM_FORMAT_YVU420_ANDROID &&
        (!data->strides[1] || !data->strides[2] ||
         data->fds[1] < 0 || data->fds[2] < 0))
        return -EINVAL;
    int result = original->bo_import(bo, data);
    if (!result && data->format == DRM_FORMAT_YVU420_ANDROID) {
        bo->meta.num_planes = 3;
        copy_handles(bo);
        /* drv_bo_import fills imported strides, offsets and sizes afterward. */
    }
    return result;
}

static int plane_fd(struct bo *bo, size_t plane)
{
    /* The three YV12 planes share one allocation. The original backend owns
     * only its first descriptor; let it duplicate that descriptor for each
     * advertised plane, without creating duplicate ownership in its internals.
     */
    if (bo->meta.format == DRM_FORMAT_YVU420_ANDROID)
        plane = 0;
    return original->bo_get_plane_fd(bo, plane);
}

static void initialize(void)
{
    void *library = dlopen("libminigbm_gralloc_gbm_mesa_base.so", RTLD_NOW | RTLD_LOCAL);
    if (!library)
        return;
    struct backend *(*get_backend)(void) = dlsym(library, "init_external_backend");
    if (!get_backend)
        return;
    original = get_backend();
    if (!original || strcmp(original->name, "gbm_mesa"))
        return;
    corrected = *original;
    corrected.bo_create = create_yv12;
    corrected.bo_import = import_yv12;
    corrected.bo_get_plane_fd = plane_fd;
    __android_log_print(ANDROID_LOG_INFO, "WaydroidYV12", "Three-plane YV12 layout enabled");
}

struct backend *init_external_backend(void)
{
    pthread_once(&once, initialize);
    return corrected.name ? &corrected : NULL;
}
