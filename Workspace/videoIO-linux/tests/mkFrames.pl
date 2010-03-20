#!/usr/bin/perl
use strict;
# A little script for creating the frames for the numbers.*.avi files.  Requires
# ImageMagick.  Most users will have no need to use this script.
#
# Copyright (c) 2006 Gerald Dalley
# See "MIT.txt" in the installation directory for licensing details (especially
# when using this library on GNU/Linux). 

`mkdir frames`;
chdir 'frames';
for (my $i=0; $i<30*10; $i++) {
    my $n = sprintf "%04d", $i;
    `convert -size 96x32 xc:transparent -pointsize 24 -fill white -draw "rectangle 0,0, 1024,1024"  -fill blue -draw "text 10,24 '$n'" $n.jpg`;
}