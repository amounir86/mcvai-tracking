## makefile
##   makefile for the ffmpeg plugin for videoIO.
##
## Copyright (c) 2006,2007,2008 Gerald Dalley
## See "MIT.txt" in the installation directory for licensing details 
## (especially when using this library on GNU/Linux). 

##############################################################################
##### Contents ###############################################################
##############################################################################

# This makefile has several sections:
#
#  Usage:
#    describes how to use this makefile for common cases.
#
#  Configuration: 
#    describes environment variables that affect the build process.  Most
#    users will be able to just follow the instructions in the "Usage" 
#    section.
#
#  Pseudo-targets:
#    describes the pseudo-target trees.  Most users will want to compile
#    using one or more pseudo-targets.
#
#  Echo protocol tester:
#    Real targets for the echo targets.  These targets are for the echo
#    plugins.  It is essentially a souped-up "Hello World" for our plugin 
#    architecture and can be used to test and debug the internal communication
#    protocols.
#
#  videoReader/videoWriter ffmpeg plugin:
#    Real targets for the various videoReader and videoWriter plugins that
#    use the 3rd-party ffmpeg library to do the low-level video I/O.
#
#  videoReader/videoWriter shared components:
#    Real targets for all videoReader/videoWriter plugins that are shared
#    by all backends.  If other 3rd-party libraries are added later (beyond
#    ffmpeg), those libraries will likely use these targets too.
#
#  Shared components:
#    Real targets shared by the echo protocol tester and all of the 
#    videoReader/videoWriter plugins.

##############################################################################
##### Usage ##################################################################
##############################################################################

# Most users will either be running:
#   32-bit ffmpeg, 32-bit Matlab, and 32-bit GNU/Linux 
# or they will be running 
#   64-bit ffmpeg, 64-bit Matlab, and 64-bit GNU/Linux.  
# These users may typically just type
#
#   make
#
# to build the libraries.  Those with mixed 32/64-bit environments can use
# the following information and table to see what build options are supported.
# Even on mixed-mode systems, just running "make" should work, but it's 
# possible that not all the desired plugins will be built.
#
# Note that users may choose to do builds from within Matlab using the
# buildVideoIO function.  It passes any string arguments to make.
#
# There are two types of plugins of note: direct and popen2.  The direct
# plugins directly call the ffmpeg libraries from the built mex functions.
# The popen2 plugins launch a separate server process that communicates with
# ffmpeg.  The former can be slightly faster and occassionally gives more
# informative error messages.  The later is more robust to instabilities in
# ffmpeg codecs and certain types of Matlab-operating system library 
# incompatabilities.
#
#   -------------------++--------------------------++--------------------------
#      User Platform   ||  Components to be Built  || 
#        |      |      || direct | popen2 | popen2 ||   Easiest Way to Build
#   Linux|ffmpeg|Matlab|| client | client | server ||
#   -----+------+------++--------+--------+--------++--------------------------
#   32   |32    |32    || 32     | 32     | 32     || make 
#      64|32    |32    || 32     | 32     | 32     || ./make32.sh
#      64|32    |   64 ||  (NONE)|    64  | 32     || ./make32ffmpeg64matlab.sh
#      64|   64 |32    ||  (NONE)| 32     |    64  || ./make64ffmpeg32matlab.sh
#      64|   64 |   64 ||    64  |    64  |    64  || make 
#   -----+------+------++--------+--------+--------++--------------------------
#      64|32+64 |32    || 32     | 32     | 32     || ./make32.sh
#      64|32+64 |32    || 32     | 32     |    64  || (**)
#      64|32+64 |   64 ||    64  |    64  | 32     || (**)
#      64|32+64 |   64 ||    64  |    64  |    64  || ./make64.sh
#   -----+------+------++--------+--------+--------++--------------------------
#      64|32    |32+64 || 32     | 32+64  | 32     || ./make32and64.sh
#      64|   64 |32+64 ||    64  | 32+64  |    64  || ./make32and64.sh
#   -----+------+------++--------+--------+--------++--------------------------
#      64|32+64 |32+64 || 32+64  | 32+64  | 32     || (**)
#      64|32+64 |32+64 || 32+64  | 32+64  |    64  || ./make32and64.sh
#   -----+------+------++--------+--------+--------++--------------------------
#
#  (*) In this table, "32+64" means both 32-bit and 64-bit are available or
#      desired.
#
# (**) These cases are less common so they do not have existing scripts.
#      Read the configuration section below and/or examine some of the 
#      make*.sh scripts for hints.

##############################################################################
##### Configuration ##########################################################
##############################################################################

# Environment variables that can be used to affect the compilation.  Any 
# unassigned variables are auto-detected by this makefile.
#
#   MEXEXT  
#     Determines what extension to use for compiled mex functions.  This
#     implicitly chooses which CPU+OS architecture the compiled mex 
#     function will support.  Examples: "mexglx" corresponds to 32-bit 
#     Matlab on GNU/Linux and "mexa64" corresponds to 64-bit Matlab on 
#     GNU/Linux.  If MEXEXT is not defined, the "mexext" script that ships 
#     with Matlab is used.  "mexext" must be in the current execution path.
#     Typically, only users wishing to do 32/64-bit cross-compilation will
#     need to define this variable.
#
#   FFMPEG_ARCH
#     Determines the version of ffmpeg to use.  Examples "-glnx86" 
#     corresponds to 32-bit ffmpeg on GNU/Linux and "-glnxa64" corresponds 
#     to 64-bit ffmpeg on GNU/Linux.  If FFMPEG_ARCH and MEXEXT correspond
#     to different architectures (e.g. if the user is using 64-bit ffmpeg 
#     with 32-bit Matlab), only the Popen2 plugins are created and not the 
#     Direct plugins.  If FFMPEG_ARCH is not defined, the 
#     ffmpeg-config-internal.pl script that ships with the videoIO library
#     is used to find the most appropriate version available.  Typically,
#     only users who have both 32-bit and 64-bit ffmpeg installed and who
#     want to use 32-bit ffmpeg need to define this variable.
#
#   MATLAB_PATH
#     Gives the path to the Matlab installation for which the videoIO 
#     library is being compiled.  If MATLAB_PATH is undefined, we use the
#     parent directory in which the "matlab" script resides.  This makefile
#     executes "$(MATLAB_PATH)/bin/mex" as the "mex" script and 
#     "$(MATLAB_PATH)/bin/mexext" as the "mexext" script, as necessary.
#     Most users have no need to define this variable.
#
#   CXXFLAGS
#     Place any additional flags needed for compilation or that affect
#     optimization choices in the CXXFLAGS variable.  Most user have
#     no need to define this variable.
#
#   LDFLAGS
#     Like CXXFLAGS, but for linking.


#### Auto-detect environment variable values ##############################
# Note: for variables where we need to do substitutions, the substituted
# variable needs a new name, so FFMPEG_ARCH --> FARCH and MEXEXT --> MEXT.

# Where's matlab, mex, and mexext?  Can be pre-defined for testing with
# multiple Matlab versions and/or if Matlab is not in the execution path.
ifndef MATLAB_PATH
  MATLAB_PATH := $(shell readlink -f `which matlab` | sed -e 's/\/bin\/matlab//')
endif

# Which mex extension will we use? (mexglx,mexa64,etc.).  Can be
# predefined for 32/64-bit cross-compilation.
ifndef MEXEXT
  MEXEXT := $(shell $(MATLAB_PATH)/bin/mexext)
endif
# be nice and remove superfluous periods
MEXT := $(subst .,,$(MEXEXT))

# Build against which ffmpeg architecture (using MathWorks-style arch 
# symbols...-glnx86,-glnxa64,etc.).  Can be predefined to force 32-bit
# vs. 64-bit ffmpeg if both are present on the current system.
ifndef FFMPEG_ARCH
  FFMPEG_ARCH := $(shell ./ffmpeg-config-internal.pl --arch)
endif
FARCH := $(subst -,,$(FFMPEG_ARCH))

### Get extra Matlab configuration info ###################################

# Which mex script to use for the compilation
MEX             := $(MATLAB_PATH)/bin/mex

# Determine the arch symbol corresponding to the chosen mex extension
MATLAB_ARCH     := $(shell ./mexext2arch.pl $(MEXT))
MATLAB_ARCH     := $(subst -,,$(MATLAB_ARCH))

# Get the architecture designation needed by GCC for binaries that will
# be linked into the compiled mex function.
MATLAB_CXX_ARCH := $(shell ./arch2gccarch.pl $(MATLAB_ARCH))

### Get extra ffmpeg configuration info ##################################

# rpath strings embed shared library locations in a binary to avoid 
# requiring the user to use LD_LIBRARY_PATH hacks.  When compiling the
# backend, here are the linker switches we'll use.
FFMPEG_BACKEND_RPATH := -Wl,-rpath=$(shell ./ffmpeg-config-internal.pl --rpath -$(FARCH))

# Only when both ffmpeg and Matlab are the same architecture can we 
# directly link to the ffmpeg libraries in our compiled mex function.
# When this is true, add the rpath info.
ifeq ($(FARCH),$(MATLAB_ARCH))
  # this variable enables the direct plugin rules
  BUILD_DIRECT        := 'true'
  # if we are building direct plugins, then give Matlab the ffmpeg rpath
  FFMPEG_DIRECT_RPATH := $(FFMPEG_BACKEND_RPATH)
endif

# -I flags and universal cflags to find the ffmpeg header files. 
FFMPEG_FLAGS := $(shell ./ffmpeg-config-internal.pl --cflags -$(FARCH)) 

# -L and -l flags (only) of the ffmpeg libraries.  These are passed 
# directly to the "mex" script, so they must not contain other 
# switches such as the rpath switches (since "mex" doesn't know what
# to do with those).
FFMPEG_LINK        := $(shell ./ffmpeg-config-internal.pl --libs -$(FARCH))

# Same as MATLAB_CXX_ARCH, but for the backends of the Popen2 plugins.
BACKEND_CXX_ARCH := $(shell ./arch2gccarch.pl $(FARCH))

### libmpeg3 configuration ##################################################

LIBMPEG3_ARCH             := $(MATLAB_ARCH)
LIBMPEG3_LINK             := -lmpeg3 -lm -lpthread
LIBMPEG3_INCL             := 
LIBMPEG3_BACKEND_LINKOPTS :=
LIBMPEG3_SRC              := contrib/libmpeg3/

### Compilation options ###################################################

# What CXXFLAGS should the "mex" script always pass along to gcc?  
CXXOPTS_MATLAB := $(shell ./unique.pl \
                      -O2 -g -I. -fPIC -D__STDC_CONSTANT_MACROS \
                      $(CXXFLAGS) $(MATLAB_CXX_ARCH) )

# What LDFLAGS shoud the "mex" script always pass along to gcc?  
LDOPTS_MATLAB := $(shell ./unique.pl \
                      -O2 -g -fPIC \
                      $(LDFLAGS) $(MATLAB_CXX_ARCH) $(FFMPEG_DIRECT_RPATH) )

# All common compilation/linking options for the "mex" script
MEXOPTS := ARCH=$(MATLAB_ARCH)

# What CXXFLAGS should be passed directly by us to gcc when compiling the
# backend (using $CC, not mex)?
CXXOPTS := $(shell ./unique.pl \
               -O2 -g -I. -fPIC -D__STDC_CONSTANT_MACROS \
               $(CXXFLAGS) $(BACKEND_CXX_ARCH) )

# Extra linker options for the ffmpeg backend
FFMPEG_BACKEND_LINKOPTS := $(FFMPEG_BACKEND_RPATH) 

# Only the g++ compiler is supported right now
ifndef CXX
  CXX := g++-4.1
endif
CXX := g++-4.1
CC := g++-4.1
MEXOPTS := CC=$(CXX) CXX=$(CXX) LD=$(CXX) $(MEXOPTS)

##############################################################################
###### Pseudo-targets ########################################################
##############################################################################

# We provide a double-hierarchy of pseudo targets.  Those compiling for 
# homogenous platforms may use the functional hierarch (the one with echo and
# ffmpeg at the top).  Those compiling for inhomogenous platforms (e.g.
# 32-bit ffmpeg with 64-bit matlab) will typically want to make multiple 
# make calls with different parts of the linkage hierarchy.  To keep these
# diagrams more compact, we use abbreviated notation taking the first letter
# from each word in the phony targets (e.g. iffmpegPopen2mex is abbreviated
# as ifpm).
#
# If FFMPEG_ARCH and MEXEXT are not binary-compatible, the direct targets
# are suppressed. 
#
# Functional Hierarchy:
#
#                       all
#                      /   \
#                     /     \
#                    /       ffmpeg  
#                   /       /      \
#                  /       /        \
#              echo   iffmpeg        offmpeg
#              /  |   |  \            |  \
#      echoPopen2 |   | iffmpegPopen2 | offmpegPopen2
#        /  \     |   |     /   \     |     /   \
#       epm eps  ed  ifd  ifpm ifps  ofd  ofpm ofps 
#
#
# Linkage Hierarchy:
#
#                       all
#                     /     \
#                   /         \
#                mex            \
#              /     \            \
#     directMex      popen2mex     server 
#      /  |  \      /   |    \    /  |   \
#     ed ifd ofd  epm ifpm ofpm eps ifps ofps
#
#     \                       / \           /
#      +----------\/---------+   +---\/----+
#          mex functions         executables
#
# Note: 
# The libmpeg3 plugin (located in /contrib) is part of the hierachy in the
# same way as ffmpeg (with the acception that there is no output (olibmpeg3)
# module
#

.PHONY: all clean echo ffmpeg iffmpeg offmpeg mex popen2mex server \
        echoPopen2    echoPopen2mex    echoPopen2server    \
        iffmpegPopen2 iffmpegPopen2mex iffmpegPopen2server \
        offmpegPopen2 offmpegPopen2mex offmpegPopen2server \
        ilibmpeg3Popen2 ilibmpeg3mex ilibmpeg3server

ifdef BUILD_DIRECT
.PHONY: directMex echoDirect iffmpegDirect offmpegDirect ilibmpeg3Direct  
endif

all: echo ffmpeg

clean:
	rm -f *.o *.go *.obj *Server *.mex* *.log tests/*.log \#* *~ 

###--- Functional Hierarchy ------------------------------------------
ifdef BUILD_DIRECT
echo: echoDirect echoPopen2
else
echo: echoPopen2
endif

echoPopen2: echoPopen2mex echoPopen2server

ffmpeg: iffmpeg offmpeg

ifdef BUILD_DIRECT
iffmpeg: iffmpegDirect iffmpegPopen2
else
iffmpeg: iffmpegPopen2
endif

iffmpegPopen2: iffmpegPopen2mex iffmpegPopen2server 

ifdef BUILD_DIRECT
offmpeg: offmpegDirect offmpegPopen2
else
offmpeg: offmpegPopen2
endif

offmpegPopen2: offmpegPopen2mex offmpegPopen2server 

ifdef BUILD_DIRECT
iffmpeg: iffmpegDirect iffmpegPopen2
ilibmpeg3: ilibmpeg3Direct ilibmpeg3Popen2
else
ilibmpeg3: ilibmpeg3Popen2
endif

ilibmpeg3Popen2: ilibmpeg3Popen2mex ilibmpeg3Popen2server 
###--- Linkage Hierarchy ---------------------------------------------
ifdef BUILD_DIRECT
mex: directMex popen2mex
else
mex: popen2mex
endif

ifdef BUILD_DIRECT
directMex: echoDirect iffmpegDirect offmpegDirect ilibmpeg3Direct
endif

popen2mex: echoPopen2mex iffmpegPopen2mex  offmpegPopen2mex ilibmpeg3Popen2mex

server: iffmpegPopen2server offmpegPopen2server ilibmpeg3Popen2server

###--- Leaf Pseudo-Targets -------------------------------------------
ifdef BUILD_DIRECT
echoDirect:          echoDirect.$(MEXT) 
endif

echoPopen2mex:       echoPopen2.$(MEXT)

echoPopen2server:    echoPopen2Server

ifdef BUILD_DIRECT
iffmpegDirect:       videoReader_ffmpegDirect.$(MEXT)
endif

iffmpegPopen2mex:    videoReader_ffmpegPopen2.$(MEXT)

iffmpegPopen2server: videoReader_ffmpegPopen2Server

ifdef BUILD_DIRECT
offmpegDirect:       videoWriter_ffmpegDirect.$(MEXT)
endif

offmpegPopen2mex:    videoWriter_ffmpegPopen2.$(MEXT)

offmpegPopen2server: videoWriter_ffmpegPopen2Server

ifdef BUILD_DIRECT
ilibmpeg3Direct:     videoReader_libmpeg3Direct.$(MEXT)
endif

ilibmpeg3Popen2mex:  videoReader_libmpeg3Popen2.$(MEXT)

ilibmpeg3Popen2server: videoReader_libmpeg3Popen2Server

##############################################################################
###### ECHO PROTOCOL TESTER ##################################################
##############################################################################

###--- popen2 version ------------------------------------------------
echoPopen2.$(MEXT): mexClientPopen2.$(MEXT).o debug.$(MEXT).o popen2.$(MEXT).o
	$(MEX) -cxx $(MEXOPTS) CXXFLAGS\#'$(LDOPTS_MATLAB)' $^ -output $@

echoPopen2Server: echo.$(FARCH).o mexServerStdio.$(FARCH).o debug.$(FARCH).o
	$(CC) $(CXXOPTS) $^ -o $@

echo.$(FARCH).o: echo.cpp debug.h matarray.h handleMexRequest.h
	$(CC) -c $(CXXOPTS) $< -o $@

###--- direct version ------------------------------------------------
ifdef BUILD_DIRECT
echoDirect.$(MEXT): echo.$(MEXT).o mexClientDirect.$(MEXT).o debug.$(MEXT).o 
	$(MEX) -cxx $(MEXOPTS) CXXFLAGS\#'$(LDOPTS_MATLAB)' $^ -output $@

echo.$(MEXT).o: echo.cpp debug.h matarray.h handleMexRequest.h
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@' $< 
endif

##############################################################################
###### VIDEOREADER/VIDEOWRITER FFMPEG PLUGIN #################################
##############################################################################

###=== ffmpeg videoReader plugin =========================================

###--- ffmpeg videoReader plugin using popen2 ------------------------
videoReader_ffmpegPopen2.$(MEXT): mexClientPopen2.$(MEXT).o debug.$(MEXT).o popen2.$(MEXT).o
	$(MEX) -cxx $(MEXOPTS) CXXFLAGS\#'$(LDOPTS_MATLAB)' $^ -output $@ 

videoReader_ffmpegPopen2Server: mexServerStdio.$(FARCH).o videoReaderWrapper.$(FARCH).o FfmpegIVideo.$(FARCH).o FfmpegCommon.$(FARCH).o registry.$(FARCH).o debug.$(FARCH).o
	$(CC) $(CXXOPTS) $^ $(FFMPEG_LINK) $(FFMPEG_BACKEND_LINKOPTS) -o $@

FfmpegIVideo.$(FARCH).o: FfmpegIVideo.cpp FfmpegIVideo.h debug.h IVideo.h parse.h 
	$(CC) -c $(CXXOPTS) $(FFMPEG_FLAGS) $< -o $@

###--- ffmpeg videoReader plugin via direct function calls  ----------
ifdef BUILD_DIRECT
videoReader_ffmpegDirect.$(MEXT): videoReaderWrapper.$(MEXT).o FfmpegIVideo.$(MEXT).o FfmpegCommon.$(MEXT).o registry.$(MEXT).o debug.$(MEXT).o mexClientDirect.$(MEXT).o 
	$(MEX) -cxx $(MEXOPTS) CXXFLAGS\#'$(LDOPTS_MATLAB)' $^ $(FFMPEG_LINK) -output $@

FfmpegIVideo.$(MEXT).o: FfmpegIVideo.cpp FfmpegIVideo.h debug.h IVideo.h parse.h 
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) $(FFMPEG_FLAGS) -o $@' $^
endif

###=== ffmpeg videoWriter plugin =========================================

###--- ffmpeg videoWriter plugin using popen2 ------------------------
videoWriter_ffmpegPopen2.$(MEXT): mexClientPopen2.$(MEXT).o debug.$(MEXT).o popen2.$(MEXT).o
	$(MEX) -cxx $(MEXOPTS) CXXFLAGS\#'$(LDOPTS_MATLAB)' $^ -output $@ 

videoWriter_ffmpegPopen2Server: mexServerStdio.$(FARCH).o videoWriterWrapper.$(FARCH).o FfmpegOVideo.$(FARCH).o FfmpegCommon.$(FARCH).o registry.$(FARCH).o debug.$(FARCH).o
	$(CC) $(CXXOPTS) $^ $(FFMPEG_LINK) $(FFMPEG_BACKEND_LINKOPTS) -o $@

FfmpegOVideo.$(FARCH).o: FfmpegOVideo.cpp FfmpegOVideo.h debug.h IVideo.h parse.h 
	$(CC) -c $(CXXOPTS) $(FFMPEG_FLAGS) $< -o $@

###--- ffmpeg videoWriter plugin via direct function calls  ----------
ifdef BUILD_DIRECT
videoWriter_ffmpegDirect.$(MEXT): videoWriterWrapper.$(MEXT).o FfmpegOVideo.$(MEXT).o FfmpegCommon.$(MEXT).o registry.$(MEXT).o debug.$(MEXT).o mexClientDirect.$(MEXT).o 
	$(MEX) -cxx $(MEXOPTS) CXXFLAGS\#'$(LDOPTS_MATLAB)' $^ $(FFMPEG_LINK) -output $@

FfmpegOVideo.$(MEXT).o: FfmpegOVideo.cpp FfmpegOVideo.h debug.h IVideo.h parse.h 
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) $(FFMPEG_FLAGS) -o $@' $^ 
endif

###=== ffmpeg shared =====================================================

###--- ffmpeg shared using popen2 ------------------------------------

FfmpegCommon.$(FARCH).o: FfmpegCommon.cpp debug.h FfmpegCommon.h
	$(CC) -c $(CXXOPTS) $(FFMPEG_FLAGS) $< -o $@

###--- ffmpeg shared via direct function calls -----------------------

ifdef BUILD_DIRECT
FfmpegCommon.$(MEXT).o: FfmpegCommon.cpp debug.h FfmpegCommon.h
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) $(FFMPEG_FLAGS) -o $@' $< 
endif

##############################################################################
###### VIDEOREADER/VIDEOWRITER LIBMPEG3 PLUGIN #################################
##############################################################################

###=== libmpeg3 videoReader plugin =========================================

###--- libmpeg3 videoReader plugin using popen2 ------------------------
videoReader_libmpeg3Popen2.$(MEXT): mexClientPopen2.$(MEXT).o debug.$(MEXT).o popen2.$(MEXT).o
	$(MEX) -cxx $(MEXOPTS) CXXFLAGS\#'$(LDOPTS_MATLAB)' $^ -output $@ 

videoReader_libmpeg3Popen2Server: mexServerStdio.$(FARCH).o videoReaderWrapper.$(FARCH).o Libmpeg3IVideo.$(FARCH).o  registry.$(FARCH).o debug.$(FARCH).o
	$(CC) $(CXXOPTS) $^ $(LIBMPEG3_LINK) $(LIBMPEG3_BACKEND_LINKOPTS) -o $@

Libmpeg3IVideo.$(FARCH).o: $(LIBMPEG3_SRC)Libmpeg3IVideo.cpp $(LIBMPEG3_SRC)Libmpeg3IVideo.h debug.h IVideo.h parse.h 
	$(CC) -c $(CXXOPTS) $(LIBMPEG3_INCL) $< -o $@

###--- libmpeg3 videoReader plugin via direct function calls  ----------
ifdef BUILD_DIRECT
videoReader_libmpeg3Direct.$(MEXT): videoReaderWrapper.$(MEXT).o Libmpeg3IVideo.$(MEXT).o registry.$(MEXT).o debug.$(MEXT).o mexClientDirect.$(MEXT).o 
	$(MEX) -cxx $(MEXOPTS) CXXFLAGS\#'$(LDOPTS_MATLAB)' $^ $(LIBMPEG3_LINK) -output $@

Libmpeg3IVideo.$(MEXT).o: $(LIBMPEG3_SRC)Libmpeg3IVideo.cpp $(LIBMPEG3_SRC)Libmpeg3IVideo.h debug.h IVideo.h parse.h 
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@' $^
endif

##############################################################################
###### VIDEOREADER/VIDEOWRITER-SPECIFIC SHARED COMPONENTS ####################
##############################################################################

###--- for linking to the server executables -------------------------

debug.$(FARCH).o: debug.cpp debug.h
	$(CC) -c $(CXXOPTS) $< -o $@

registry.$(FARCH).o: registry.cpp registry.h debug.h handle.h IVideo.h
	$(CC) -c $(CXXOPTS) $< -o $@

videoReaderWrapper.$(FARCH).o: videoReaderWrapper.cpp handleMexRequest.h IVideo.h matarray.h debug.h
	$(CC) -c $(CXXOPTS) $< -o $@

videoWriterWrapper.$(FARCH).o: videoWriterWrapper.cpp handleMexRequest.h OVideo.h matarray.h debug.h parse.h 
	$(CC) -c $(CXXOPTS) $< -o $@

###--- for linking to the mex components -----------------------------

debug.$(MEXT).o: debug.cpp debug.h 
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@' $< 

registry.$(MEXT).o: registry.cpp registry.h debug.h handle.h IVideo.h
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@' $< 

popen2.$(MEXT).o: popen2.cpp popen2.h
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@' $<

videoReaderWrapper.$(MEXT).o: videoReaderWrapper.cpp handleMexRequest.h IVideo.h matarray.h debug.h
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@' $<

videoWriterWrapper.$(MEXT).o: videoWriterWrapper.cpp handleMexRequest.h OVideo.h matarray.h debug.h parse.h 
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@' $<

##############################################################################
###### SHARED COMPONENTS #####################################################
##############################################################################

###--- mex-compiled shared components --------------------------------

ifdef BUILD_DIRECT
mexClientDirect.$(MEXT).o: mexClientDirect.cpp debug.h matarray.h handleMexRequest.h
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@'  $<
endif

mexClientPopen2.$(MEXT).o: mexClientPopen2.cpp debug.h popen2.h matarray.h pipecomm.h MatlabHelpers.h
	$(MEX) -c $(MEXOPTS) CXXFLAGS\#'$(CXXOPTS_MATLAB) -o $@' $<

###--- gcc-compiled shared components --------------------------------

mexServerStdio.$(FARCH).o: mexServerStdio.cpp debug.h matarray.h pipecomm.h handleMexRequest.h
	$(CC) -c $(CXXOPTS) $< -o $@
