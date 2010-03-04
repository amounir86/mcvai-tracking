#!/bin/bash

## Use this script to build a the ffmpegPopen2 videoIO plugins assuming that
## 32-bit ffmpeg and 64-bit Matlab are to be used (on a 64-bit GNU/Linux
## system).

make $BASH_ARGV MEXEXT=mexa64 FFMPEG_ARCH=-glnx86
