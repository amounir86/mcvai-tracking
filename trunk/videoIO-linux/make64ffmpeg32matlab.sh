#!/bin/bash

## Use this script to build a the ffmpegPopen2 videoIO plugins assuming that
## 64-bit ffmpeg and 32-bit Matlab are to be used (on a 64-bit GNU/Linux
## system).

make $BASH_ARGV MEXEXT=mexglx FFMPEG_ARCH=-glnxa64
