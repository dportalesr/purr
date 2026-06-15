#include "CEcho.h"
#include "speex/speex_echo.h"
#include "speex/speex_preprocess.h"
#include <stdlib.h>

/* SpeexDSP's echo API is int16-only regardless of the float build, so the
 * shim converts at the boundary. The scratch frames live on the handle to
 * keep cecho_process allocation-free. */
struct CEcho {
    SpeexEchoState *echo;
    SpeexPreprocessState *preprocess;
    int frameSize;
    spx_int16_t *micFrame;
    spx_int16_t *refFrame;
    spx_int16_t *outFrame;
};

static spx_int16_t floatToPCM(float value) {
    float scaled = value * 32768.0f;
    if (scaled > 32767.0f) scaled = 32767.0f;
    if (scaled < -32768.0f) scaled = -32768.0f;
    return (spx_int16_t)scaled;
}

CEcho *cecho_create(int frameSize, int filterLength, int sampleRate) {
    CEcho *echo = calloc(1, sizeof(CEcho));
    if (!echo) return NULL;

    echo->frameSize = frameSize;
    echo->echo = speex_echo_state_init(frameSize, filterLength);
    echo->preprocess = speex_preprocess_state_init(frameSize, sampleRate);
    echo->micFrame = calloc(frameSize, sizeof(spx_int16_t));
    echo->refFrame = calloc(frameSize, sizeof(spx_int16_t));
    echo->outFrame = calloc(frameSize, sizeof(spx_int16_t));

    if (!echo->echo || !echo->preprocess || !echo->micFrame || !echo->refFrame
        || !echo->outFrame) {
        cecho_destroy(echo);
        return NULL;
    }

    speex_echo_ctl(echo->echo, SPEEX_ECHO_SET_SAMPLING_RATE, &sampleRate);
    /* Couple the preprocessor to the echo state. The preprocessor's spectral
     * gain stage then applies residual echo suppression on top of the linear
     * canceller. Denoising is left at its default (on) because that gain
     * stage is the same machinery the residual echo suppressor runs through;
     * AGC, VAD and dereverb default to off and stay off. */
    speex_preprocess_ctl(echo->preprocess, SPEEX_PREPROCESS_SET_ECHO_STATE, echo->echo);

    return echo;
}

void cecho_process(CEcho *echo, const float *mic, const float *reference, float *out) {
    for (int i = 0; i < echo->frameSize; i++) {
        echo->micFrame[i] = floatToPCM(mic[i]);
        echo->refFrame[i] = floatToPCM(reference[i]);
    }
    speex_echo_cancellation(echo->echo, echo->micFrame, echo->refFrame, echo->outFrame);
    speex_preprocess_run(echo->preprocess, echo->outFrame);
    for (int i = 0; i < echo->frameSize; i++) {
        out[i] = (float)echo->outFrame[i] / 32768.0f;
    }
}

void cecho_destroy(CEcho *echo) {
    if (!echo) return;
    if (echo->echo) speex_echo_state_destroy(echo->echo);
    if (echo->preprocess) speex_preprocess_state_destroy(echo->preprocess);
    free(echo->micFrame);
    free(echo->refFrame);
    free(echo->outFrame);
    free(echo);
}
