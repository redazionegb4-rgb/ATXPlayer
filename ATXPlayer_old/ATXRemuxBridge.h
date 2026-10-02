#ifndef ATXRemuxBridge_h
#define ATXRemuxBridge_h
#ifdef __cplusplus
extern "C" {
#endif
/// Remuxes a remote/local Matroska-compatible input into fragmented MP4 without re-encoding.
/// Returns 0 on success, otherwise an FFmpeg error code.
int atx_remux_to_mp4(const char *input_url, const char *output_path);
#ifdef __cplusplus
}
#endif
#endif
