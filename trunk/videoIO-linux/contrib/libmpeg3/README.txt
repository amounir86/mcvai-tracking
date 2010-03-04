UNOFFICIAL PLUGIN

Libmpeg3 plugin for the videoIO toolbox

This plugin allows you to use libmpeg3 to read in mpeg1 and mpeg2
video files via the @videoReader object in Matlab. The main advantage
over ffmpeg is that one can seek quickly in an mpeg1 or mpeg2 files by
using a .toc file. A .toc files is a table of contents file that can
be created using the mpeg3toc utility supplied with libmpeg3. The
videoIO plugin will also automatically create such a file if a .mpg is
read. This .toc file will be created in the same directory as the
specified .mpg. 

This plugin requires libmpeg3 version 1.7+. There is an
INSTALL.libmpeg3.sh script that can be run on linux to install
libmpeg3. 

I would say later version of libmpeg3 can be used but they seem to
change the API occasionally. 

To make the libmpeg3 plugin just run

make ilibmpeg3

in the main videoIO directory. (Again this requires libmpeg3 to be
installed on your system).

Good Luck :),
-Michael Siracusa
