#!/bin/bash

## Use this script to build a complete complement of 64-bit videoIO plugins
## assuming that 64-bit ffmpeg and 64-bit Matlab are to be used (on a 64-bit 
## GNU/Linux system).

make $BASH_ARGV MEXEXT=mexa64 FFMPEG_ARCH=-glnxa64
