#!/usr/bin/perl
use strict;

if (@ARGV != 1) {
    print <<EOM;
arch2gccarch.pl <arch>
  Translates a MathWorks-style architecture string into a GCC -m<arch>
  compilation option string.  

  This is a convenience script used by the videoIO makefile.
EOM
    exit(1);
}

my $arch = $ARGV[0];
if (!($arch =~ /^\-/)) {
    $arch = '-'.$arch;
}

if      ($arch eq "-glnx86" ) { # 32-bit GNU/Linux
    print "-m32";
} elsif ($arch eq "-glnxa64") { # 64-bit GNU/Linux
    print "-m64";
} else {
    die "Unsupported architecture.\n";
}
print "\n";
