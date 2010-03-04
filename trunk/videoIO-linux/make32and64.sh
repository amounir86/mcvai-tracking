#!/bin/bash

## Use this script to build a complete complement of 32-bit and 64-bit videoIO 
## plugins on 64-bit Linux machines that have 32-bit ffmpeg, 64-bit ffmpeg, 
## 32-bit Matlab, and 64-bit Matlab.

# Build 32-bit mex components.
make mex MEXEXT=mexglx FFMPEG_ARCH=-glnx86 

# Build 64-bit mex components
make mex MEXEXT=mexa64 FFMPEG_ARCH=-glnxa64

# We must choose one backend for the popen2 plugins to avoid filename clashes.
# For now, we will prefer 64-bit backends.  
#
# FUTURE: The more general solution would be to allow backends that avoid the 
# conflicts, but this would complicate mexClientPopen2.cpp and it's unlikely 
# that anyone will need that functionality.
make server MEXEXT=mexa64 FFMPEG_ARCH=-glnxa64


