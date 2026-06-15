/* Minimal build configuration for the vendored SpeexDSP echo canceller.
 *
 * SpeexDSP normally generates config.h via autotools. Only the echo path is
 * compiled here (mdf.c + preprocess.c + filterbank.c + the KISS FFT backend),
 * so a hand-written float-build configuration is all that is required. Every
 * vendored SpeexDSP source guards `#include "config.h"` behind HAVE_CONFIG_H,
 * which the CEcho target defines in Package.swift.
 */
#ifndef CECHO_CONFIG_H
#define CECHO_CONFIG_H

#define FLOATING_POINT
#define USE_KISS_FFT
#define EXPORT
#define HAVE_STDINT_H

#endif
