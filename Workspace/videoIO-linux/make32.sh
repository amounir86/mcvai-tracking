#!/bin/bash

## Use this script to build a complete complement of 32-bit videoIO plugins
## assuming that 32-bit ffmpeg and 32-bit Matlab are to be used (on either a
## 32-bit or 64-bit GNU/Linux system).

make $BASH_ARGV MEXEXT=mexglx FFMPEG_ARCH=-glnx86
