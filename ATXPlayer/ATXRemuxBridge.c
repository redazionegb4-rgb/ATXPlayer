#include "ATXRemuxBridge.h"
#include <libavformat/avformat.h>
#include <libavcodec/codec_par.h>
#include <libavutil/avutil.h>
#include <libavutil/mem.h>
#include <libavutil/error.h>
#include <errno.h>

int atx_remux_to_mp4(const char *input_url, const char *output_path) {
    AVFormatContext *in_ctx = NULL;
    AVFormatContext *out_ctx = NULL;
    AVPacket *pkt = NULL;
    int *stream_map = NULL;
    int ret = 0, out_index = 0;

    avformat_network_init();
    AVDictionary *opts = NULL;
    av_dict_set(&opts, "rw_timeout", "20000000", 0);
    av_dict_set(&opts, "user_agent", "ATXPlayer/5.1", 0);

    ret = avformat_open_input(&in_ctx, input_url, NULL, &opts);
    av_dict_free(&opts);
    if (ret < 0) goto end;
    ret = avformat_find_stream_info(in_ctx, NULL);
    if (ret < 0) goto end;

    ret = avformat_alloc_output_context2(&out_ctx, NULL, "mp4", output_path);
    if (ret < 0 || !out_ctx) { if (ret >= 0) ret = AVERROR_UNKNOWN; goto end; }

    stream_map = av_calloc(in_ctx->nb_streams, sizeof(*stream_map));
    if (!stream_map) { ret = AVERROR(ENOMEM); goto end; }
    for (unsigned i = 0; i < in_ctx->nb_streams; i++) stream_map[i] = -1;

    for (unsigned i = 0; i < in_ctx->nb_streams; i++) {
        AVStream *in_stream = in_ctx->streams[i];
        enum AVMediaType type = in_stream->codecpar->codec_type;
        if (type != AVMEDIA_TYPE_VIDEO && type != AVMEDIA_TYPE_AUDIO) continue;
        AVStream *out_stream = avformat_new_stream(out_ctx, NULL);
        if (!out_stream) { ret = AVERROR(ENOMEM); goto end; }
        stream_map[i] = out_index++;
        ret = avcodec_parameters_copy(out_stream->codecpar, in_stream->codecpar);
        if (ret < 0) goto end;
        out_stream->codecpar->codec_tag = 0;
        out_stream->time_base = in_stream->time_base;
    }

    if (!(out_ctx->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&out_ctx->pb, output_path, AVIO_FLAG_WRITE);
        if (ret < 0) goto end;
    }

    AVDictionary *mux_opts = NULL;
    // Fragmented MP4 lets AVFoundation open the file without a final moov rewrite.
    av_dict_set(&mux_opts, "movflags", "frag_keyframe+empty_moov+default_base_moof+faststart", 0);
    ret = avformat_write_header(out_ctx, &mux_opts);
    av_dict_free(&mux_opts);
    if (ret < 0) goto end;

    pkt = av_packet_alloc();
    if (!pkt) { ret = AVERROR(ENOMEM); goto end; }

    while ((ret = av_read_frame(in_ctx, pkt)) >= 0) {
        if (pkt->stream_index < 0 || pkt->stream_index >= (int)in_ctx->nb_streams || stream_map[pkt->stream_index] < 0) {
            av_packet_unref(pkt); continue;
        }
        AVStream *in_stream = in_ctx->streams[pkt->stream_index];
        int mapped = stream_map[pkt->stream_index];
        AVStream *out_stream = out_ctx->streams[mapped];
        pkt->stream_index = mapped;
        pkt->pts = av_rescale_q_rnd(pkt->pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
        pkt->dts = av_rescale_q_rnd(pkt->dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
        pkt->duration = av_rescale_q(pkt->duration, in_stream->time_base, out_stream->time_base);
        pkt->pos = -1;
        ret = av_interleaved_write_frame(out_ctx, pkt);
        av_packet_unref(pkt);
        if (ret < 0) goto end;
    }
    if (ret == AVERROR_EOF) ret = 0;
    if (ret >= 0) ret = av_write_trailer(out_ctx);

end:
    if (pkt) av_packet_free(&pkt);
    if (in_ctx) avformat_close_input(&in_ctx);
    if (out_ctx) {
        if (!(out_ctx->oformat->flags & AVFMT_NOFILE) && out_ctx->pb) avio_closep(&out_ctx->pb);
        avformat_free_context(out_ctx);
    }
    if (stream_map) av_free(stream_map);
    avformat_network_deinit();
    return ret;
}
