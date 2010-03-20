#!/usr/bin/perl
use strict;

if (@ARGV != 1) {
    print <<EOM;
mexext2arch.pl <mexext>
  Translates a mex extension <mexext> to a MathWorks-style architecture string.
  The leading dash is omitted to simplify the creation of ARCH=<arch> strings.

  This is a convenience script used by the videoIO makefile.
EOM
    exit(1);
} 

if      ($ARGV[0] eq "mexglx" ) { # 32-bit GNU/Linux
    print "glnx86";
} elsif ($ARGV[0] eq "mexa64" ) { # 64-bit GNU/Linux
    print "glnxa64";
} elsif ($ARGV[0] eq "mexmac" ) { # Macintosh (PPC)
    print "mac";
} elsif ($ARGV[0] eq "mexmaci") { # Macintosh (Intel)
    print "maci";
} elsif ($ARGV[0] eq "mexs64" ) { # 64-bit Solaris SPARC
    print "sol64";
} elsif ($ARGV[0] eq "mexw32" ) { # 32-bit Windows
    print "pcwin";
} elsif ($ARGV[0] eq "mexw64" ) { # 64-bit Windows
    print "pcwin64";
} else {
    die "Unrecognized mex extension.\n";
}
print "\n";
