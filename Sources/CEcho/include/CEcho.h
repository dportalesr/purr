#ifndef CECHO_H
#define CECHO_H

/* Acoustic echo canceller.
 *
 * A thin C wrapper over the vendored SpeexDSP echo canceller (mdf.c) coupled
 * with the SpeexDSP preprocessor for residual (non-linear) echo suppression.
 * Used by EchoCanceller.swift to strip system-audio echo out of the meeting
 * microphone signal. */

typedef struct CEcho CEcho;

/* Creates a canceller. `frameSize` and `filterLength` are in samples at
 * `sampleRate` Hz. Returns NULL on allocation failure. */
CEcho *cecho_create(int frameSize, int filterLength, int sampleRate);

/* Cancels echo for exactly one frame (`frameSize` samples).
 *   mic       - near-end signal: local speech plus leaked echo
 *   reference - far-end signal that leaked into the mic (the system audio)
 *   out       - receives the cleaned near-end signal
 * All three buffers are `frameSize` floats in [-1, 1]; `out` must not alias
 * `mic` or `reference`. */
void cecho_process(CEcho *echo, const float *mic, const float *reference, float *out);

void cecho_destroy(CEcho *echo);

#endif
