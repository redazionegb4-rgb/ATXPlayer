#include "CFFmpegBridge.h"

#include <dlfcn.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

typedef int (*fks_execute_function)(int argc, char **argv);
typedef void (*fks_cancel_function)(long session_id);
typedef void (*fks_set_report_callback_function)(void (*callback)(int, float, float, int64_t, double, double, double));
typedef void (*fks_set_log_callback_function)(void (*callback)(void *, int, const char *, va_list));
typedef void (*fks_set_session_id_function)(long session_id);
typedef void (*fks_set_runtime_log_callback_function)(void (*callback)(void *, int, const char *, va_list));

static void *fks_symbol(const char *name) {
    return dlsym(RTLD_DEFAULT, name);
}

typedef struct {
    void *context;
    fks_log_callback log_callback;
    fks_statistics_callback statistics_callback;
} fks_execution_context;

/* FFmpeg's CLI entry points use process-global state and are intentionally serialized by Swift. */
static fks_execution_context *fks_current_context;

static void fks_log(void *av_context, int level, const char *format, va_list arguments) {
    (void)av_context;
    fks_execution_context *execution = fks_current_context;
    if (execution == NULL || execution->log_callback == NULL) {
        return;
    }

    va_list arguments_copy;
    va_copy(arguments_copy, arguments);
    int length = vsnprintf(NULL, 0, format, arguments_copy);
    va_end(arguments_copy);
    if (length < 0) {
        return;
    }

    char *message = malloc((size_t)length + 1);
    if (message == NULL) {
        return;
    }
    vsnprintf(message, (size_t)length + 1, format, arguments);
    execution->log_callback(execution->context, level, message);
    free(message);
}

static void fks_statistics(int frame, float fps, float quality, int64_t size, double time, double bitrate, double speed) {
    fks_execution_context *execution = fks_current_context;
    if (execution != NULL && execution->statistics_callback != NULL) {
        execution->statistics_callback(execution->context, frame, fps, quality, size, time, bitrate, speed);
    }
}

static int32_t fks_execute(
    int is_ffprobe,
    int64_t session_id,
    int32_t argument_count,
    const char *const *arguments,
    void *context,
    fks_log_callback log_callback,
    fks_statistics_callback statistics_callback
) {
    fks_execute_function execute_function = (fks_execute_function)fks_symbol(is_ffprobe ? "ffprobe_execute" : "ffmpeg_execute");
    if (execute_function == NULL) {
        return -127;
    }

    int argc = argument_count + 1;
    char **argv = calloc((size_t)argc + 1, sizeof(char *));
    if (argv == NULL) {
        return -12;
    }
    argv[0] = is_ffprobe ? "ffprobe" : "ffmpeg";
    for (int32_t index = 0; index < argument_count; index++) {
        argv[index + 1] = (char *)arguments[index];
    }

    fks_execution_context execution = {context, log_callback, statistics_callback};
    fks_current_context = &execution;
    fks_set_session_id_function set_session_id = (fks_set_session_id_function)fks_symbol("ffmpegkit_set_session_id");
    fks_set_runtime_log_callback_function set_runtime_log_callback =
        (fks_set_runtime_log_callback_function)fks_symbol("ffmpegkit_set_log_callback");
    fks_set_log_callback_function set_log_callback = (fks_set_log_callback_function)fks_symbol("av_log_set_callback");
    fks_set_report_callback_function set_statistics_callback = (fks_set_report_callback_function)fks_symbol("set_report_callback");
    if (set_session_id != NULL) {
        set_session_id((long)session_id);
    }
    if (set_runtime_log_callback != NULL) {
        set_runtime_log_callback(fks_log);
    }
    if (set_log_callback != NULL) {
        set_log_callback(fks_log);
    }
    if (!is_ffprobe && set_statistics_callback != NULL) {
        set_statistics_callback(fks_statistics);
    }

    int32_t result = execute_function(argc, argv);

    if (!is_ffprobe && set_statistics_callback != NULL) {
        set_statistics_callback(NULL);
    }
    fks_current_context = NULL;
    free(argv);
    return result;
}

int32_t fks_ffmpeg_execute(
    int64_t session_id,
    int32_t argument_count,
    const char *const *arguments,
    void *context,
    fks_log_callback log_callback,
    fks_statistics_callback statistics_callback
) {
    return fks_execute(0, session_id, argument_count, arguments, context, log_callback, statistics_callback);
}

int32_t fks_ffprobe_execute(
    int64_t session_id,
    int32_t argument_count,
    const char *const *arguments,
    void *context,
    fks_log_callback log_callback
) {
    return fks_execute(1, session_id, argument_count, arguments, context, log_callback, NULL);
}

void fks_cancel(int64_t session_id) {
    fks_cancel_function cancel_function = (fks_cancel_function)fks_symbol("cancel_operation");
    if (cancel_function != NULL) {
        cancel_function((long)session_id);
    }
}

int32_t fks_is_linked(void) {
    return fks_symbol("ffmpeg_execute") != NULL && fks_symbol("ffprobe_execute") != NULL;
}

const char *fks_ffmpeg_version(void) {
    typedef const char *(*fks_version_function)(void);
    fks_version_function version_function = (fks_version_function)fks_symbol("av_version_info");
    return version_function == NULL ? "unknown" : version_function();
}
