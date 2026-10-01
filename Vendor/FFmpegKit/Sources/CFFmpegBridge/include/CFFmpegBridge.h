#ifndef C_FFMPEG_BRIDGE_H
#define C_FFMPEG_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*fks_log_callback)(void *context, int32_t level, const char *message);
typedef void (*fks_statistics_callback)(
    void *context,
    int32_t frame,
    float fps,
    float quality,
    int64_t size,
    double time,
    double bitrate,
    double speed
);

int32_t fks_ffmpeg_execute(
    int64_t session_id,
    int32_t argument_count,
    const char *const *arguments,
    void *context,
    fks_log_callback log_callback,
    fks_statistics_callback statistics_callback
);

int32_t fks_ffprobe_execute(
    int64_t session_id,
    int32_t argument_count,
    const char *const *arguments,
    void *context,
    fks_log_callback log_callback
);

void fks_cancel(int64_t session_id);
int32_t fks_is_linked(void);
const char *fks_ffmpeg_version(void);

#ifdef __cplusplus
}
#endif

#endif
