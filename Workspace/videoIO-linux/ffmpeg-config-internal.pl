#!/usr/bin/perl
use strict;

## Many libraries are kind enough to provide a script that lets makefiles
## and configure scripts easily be able to tell how to adjust their
## compilation options to be able to find header files and know which
## libraries must be linked.  As of 1 June 2007, ffmpeg doesn't provide
## one, so we'll hack up an attempt.  In doing so, we add a few extra 
## useful features.  
##
## Run this script with no arguments for usage instructions.
##
## If this script gets much more complicated, it may be worth the 
## overhead of using autoconf.
##
## This is a convenience script used by the videoIO makefile.
##
## Written by Gerald Dalley

usage() unless (@ARGV > 0);

# Parse command line args
my $showcflags = 0;
my $showlibs   = 0;
my $showstatic = 0;
my $showrpath  = 0;
my $showarch   = 0;
my $bits64     = osIs64bit();
foreach my $arg (@ARGV) {
    if    ($arg eq "--cflags")     { $showcflags = 1; }
    elsif ($arg eq "--libs")       { $showlibs   = 1; }
    elsif ($arg eq "--staticlibs") { $showstatic = 1; }
    elsif ($arg eq "--rpath")      { $showrpath  = 1; }
    elsif ($arg eq "--arch")       { $showarch   = 1; }
    elsif ($arg eq "-glnx86")      { $bits64     = 0; }
    elsif ($arg eq "-glnxa64")     { $bits64     = 1; }
    else { usage(); }
}

# We use global variables here since most of our function calls modify most
# of these arrays.
our @extracflags;
our @linkPath;   
our @includePath;
our @libsToLink;
our @staticLibPathnames; # not displayed right now
our $arch = ($bits64 ? "-glnxa64" : "-glnx86");

# pre-populate with defaults
foreach my $bitness (reverse('', ($bits64?'64':'32'))) {
    foreach my $dir ('/usr/local', '/usr') {
        push @linkPath,    "$dir/lib$bitness";
        push @includePath, "$dir/include$bitness";
    }
}
@linkPath    = unique(@linkPath);
push @includePath, "/usr/include", "/usr/local/include"; 
@includePath = reverse(sort(unique(@includePath)));

# Gather data
ffmpegLibSearch();

# Compose output
my $cflags = join(" ", (map { "-I$_" } @includePath),
                        $bits64?'-m64':'-m32',
                        @extracflags);

my $libs   = join(" ", ((map { "-L$_" } @linkPath), 
                        (map { "-l$_" } @libsToLink)));

my $slibs  = join(" ", @staticLibPathnames);

my $rpath  = join(':', @linkPath);

# Print desired outputs
print $cflags."\n" if ($showcflags);
print $libs."\n"   if ($showlibs);
print $slibs."\n"  if ($showstatic);
print $rpath."\n"  if ($showrpath);
print $arch."\n"   if ($showarch);

#############################################
# Determine whether we're running on a 64-bit OS
sub osIs64bit() {
    my $uname = `uname -m` || die "cannot determine the system architecture\n";
    return ($uname =~ /64$/);
}

#############################################
# Pad a string with spaces to the right
#  rpad("foo",5) --> "foo  "
sub rpad($$) {
    my ($str, $n) = @_;
    return $str.(' ' x ($n - length($str)));
}

############################################
# Execute the command line, printing the result to stdout.  Die if
# the command fails.
sub runPrintAndExit($) {
    open F, "$_[0] |" || die "Could not run '$_[0]'\n";
    while (<F>) { print; }
    close F;
    exit(0);
}

############################################
# Print usage docs and exit
sub usage() {
    print <<EMSG;
Usage: $^X [OPTIONS]
Options:
    [--cflags]     Shows GCC options for compiling ffmpeg binaries
    [--libs]       Shows GCC options for linking ffmpeg binaries
    [--staticlibs] Shows GCC options for forced-static linking ffmpeg binaries.
                     Note that unless Matlab and your OS use exactly the same
                     version of GCC, statically-linked mex functions and even
                     spawned executables will usually not load.
    [--rpath]      Shows the runtime path for running ffmpeg binaries 
    [--arch]       Shows the architectures for which binaries are found
                     Uses Matlab-compatible architecture strings (e.g.
                     "-glnx86" for 32-bit GNU/Linux, "-glnxa64" for 
                     64-bit GNU/Linux, etc.)

    [-glnx86]      Force detection of 32-bit libraries (and not 64-bit)
    [-glnxa64]     Force detection of 64-bit libraries (and not 32-bit)

If an architecture is not explicitly specified, it is auto-detected.
EMSG
exit;
}

############################################
# Remove duplicates in the list while preserving order.  The first
# instance is kept when duplicates are found.
sub unique(@) {  
    my @orig = @_;
    my %hash;
    foreach my $i (@orig) {
	$hash{$i}++;
    }
    my @pruned;
    foreach my $key (reverse @orig) {
        if ($hash{$key}-- == 1) {
            unshift @pruned, $key;
        }
    }
    return @pruned;
}

#############################################
# Search for all ffmpeg dependencies
sub ffmpegLibSearch() {
    my $option = "ffmpeg";

    # Hunt for libraries and headers we know we need
    # For certain versions of ffmpeg (all but the really old ones), swscale is
    # required, but we can detect that issue when building by doing version 
    # checks.
    if (findUsrLib($option,1, "ffmpeg/avcodec.h", "avformat","avcodec","avutil")) {
        findUsrLib($option,1, "ffmpeg/swscale.h", "swscale");
        push @extracflags, "-DFFMPEG_INCLUDE_DIR";
    } else {
        findUsrLib($option,0, "libavformat/avformat.h", "avformat");
        findUsrLib($option,0, "libavcodec/avcodec.h",   "avcodec");
        findUsrLib($option,0, "libavutil/avutil.h",     "avutil");
        findUsrLib($option,1, "libswscale/swscale.h",   "swscale");
    }
    findUsrLib($option,0, "",                 "z","dl","m");

    # When possible, look for additional dependency information embedded
    # in the libraries.
    foreach my $dir (@linkPath) {
        # dynamic libs are nice: they tell us their dependencies
        my $ext = "so";
        if (-f "$dir/libavcodec.$ext") {
            open O,"objdump -x $dir/libavcodec.$ext|";
            while (my $l = <O>) {
                if ($l =~ /NEEDED\s+lib([a-zA-Z0-9_]+).so/) {
                    findUsrLib($option, 0, "", $1);
                }
            }
            close O;
        }
        
        # but we must hard-code the possible set of 3rd party dependencies
        # when looking at the static libs.
        my $ext = "a";
        if (-f "$dir/libavcodec.$ext") {
            if (`nm $dir/libavcodec.$ext 2>&1 | grep " U vorbis_free"`) {
                findUsrLib($option, 0, "", "vorbis","vorbisenc","vorbisfile");
            }
            if (`nm $dir/libavcodec.$ext 2>&1 | grep " U ogg"`) {
                findUsrLib($option, 0, "", "ogg");
            }
            if (`nm $dir/libavcodec.$ext 2>&1 | grep " U x264"`) {
                findUsrLib($option, 0, "", "x264");
            }
            if (`nm $dir/libavcodec.$ext 2>&1 | grep " U pthread"`) {
                findUsrLib($option, 0, "", "pthread");
            }
        }
    }
}

############################################
# Search for a given set of libraries
#   $option:    friendly name of the library we're looking for
#   $optional:  if true, ignore any headers and/or libs that aren't found
#   $keyHeader: look for this header file in @includePath
#   @libs:      look for each of these in @linkPath
sub findUsrLib($$$$@) {
    my ($option, $optional, $keyHeader, @libs) = @_;

    # Search for the header file
    # (note: we no longer check for consistency between the header
    # location and the lib location since it gets trickier with
    # cross-compilation).
    if ($keyHeader) {
        my $foundHeader = 0;
        foreach my $dir (@includePath) {
            if (-f "$dir/$keyHeader") {
                $foundHeader = 1;
            }
        }
        if (!$foundHeader) {
            return 0 if ($optional);
            die "Could not find $option\'s $keyHeader header\n";
        }
    }
    
    # Look for every file that can satisfy the link request
    foreach my $lib (@libs) {
        # Search for the library
        my $foundLibrary = 0;
        my $foundPathname = "";
        foreach my $ext ("so","a") {
            foreach my $dir (@linkPath) {
                my $pathname = "$dir/lib$lib.$ext";
                if (-f $pathname) {
                    # Architecture check
                    my $myarch = getBinaryArch($pathname);
                    if ($myarch eq $arch) {
                        $foundLibrary = 1;
                        $foundPathname = $pathname if ($ext eq "a");
                    }
                }
            }                   
        }

        if ($foundLibrary) {
            @libsToLink         = unique(@libsToLink, $lib);
            @staticLibPathnames = unique(@staticLibPathnames, $foundPathname);
        } elsif (!$optional) {
            # silently proceed if optional
            die "Could not find $option\'s $lib library\n";
        }
    }

    return 1;
}

############################################
# Returns the Matlab-friendly binary architecture spec for a binary file 
# (library, executable, etc.).  Nothing returned if the architecture cannot
# be determined.
sub getBinaryArch($) {
    # objdump returns a line that looks like
    #   /usr/lib/libavutil.so:   file format elf64-x86-64
    # $archStr is this line.  $archFmt is just "elf64-x86-64".  The return 
    # value is "-glnxa64" in this case.
    my ($path) = @_;
    return if (!(-f $path));
    my $archfind = join("|", ("objdump -f '$path' 2>&1", 
                              "grep \"file format\"", "head -n 1"));
    if (my $archStr = `$archfind`) {
        if ($archStr =~ /file format\s+([^\s]+)/) {
            my $archFmt = $1;
            if ($archFmt =~ /elf32/) {
                return "-glnx86";
            } elsif ($archFmt =~ /elf64/) {
                return "-glnxa64";
            }
        }
    }
    return;
}
