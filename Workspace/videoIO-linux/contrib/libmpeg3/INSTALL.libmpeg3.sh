#!/bin/bash

# This file describes how to install libmpeg3 which is required for 
# the Libmpeg3IVideo plugin.
#
# The plugin has only been tested on Linux kernel 2.6.18
# using libmpeg3 version 1.7
#
# You can run this file as a shell script and it should do all the work for you
#
# This does some strange things because the Makefile for libmpeg3 1.7 has some 
# issues so I copy over the custom libmpeg3-1.7-Makefile from this directory 
# to do the make and install. This make file adds the -fPIC compiler flag and
# makes sure the 'make install' installs libmpeg3.a and the supporting header 
# files into /usr/local/lib and /usr/local/include
#
# This script requires wget, bunzip2, and tar

########################################
# 1. Obtain libmpeg3 1.7
########################################
# We will use wget to grab it and put it in a /tmp director
# If you don't have wget on debian you can easily install it with
# sudo apt-get install wget

# Check sourceforge.net to see if there's a newer version.  If so, change
# this variable.
export LIBMPEG3_VERSION=libmpeg3-1.8

cd /tmp 
wget http://internap.dl.sourceforge.net/sourceforge/heroines/${LIBMPEG3_VERSION}-src.tar.bz2 

# Next bunzip2 and untar
bunzip2 ${LIBMPEG3_VERSION}-src.tar.bz2
tar -xvvf ${LIBMPEG3_VERSION}-src.tar

# Move the source tree to its permanent location
sudo mv ${LIBMPEG3_VERSION} /usr/local/src/

#######################################
# 2. Make libmpeg3 
#######################################
cd /usr/local/src/${LIBMPEG3_VERSION}

# Make sure CFLAGS has -fPIC set if 64-bit
if ! uname -a | grep x86_64 > /dev/null
  then
    export CFLAGS="$CFLAGS -fPIC"
fi

# Run make.  Expect to see a lot of error messages.
make

# Run make again: At least in version 1.7, libmpeg3 has some depencency 
# tracking issues, so one must run make twice to obtain a successful build.
make

#######################################
# 3. Install
#######################################
sudo make install

# For some reason in recent builds the installation of 
# the lib and header files is commented out in the make file
# so for now we just manually install them.

# Install header files
sudo install libmpeg3.h mpeg3private.h /usr/local/include/

# Install library
OBJDIR=$(uname --machine)
sudo install $OBJDIR/libmpeg3.a /usr/local/lib/






