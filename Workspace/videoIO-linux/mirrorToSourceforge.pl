#!/usr/bin/perl
use strict;

print "This script is used by the author to synchronize his own subversion\n";
print "repository with sourceforge's.  Other users will have no use for\n";
print "this script (and it won't work for them either unless they are\n";
print "granted write permissions to that repository.\n";
print "\n";

# When using incremental updates, it's easy to get revision numbers 
# desynchronized.  When disabled, we upload the entire respository each time.
my $USE_INCREMENTAL = 0;

if ($USE_INCREMENTAL) {
  ###### INCREMENTAL VERSION
  if (!@ARGV) {
      print "USAGE:\n";
      print "  mirrorToSourceforge.pl <rev>\n";
      print "     <rev>: newest revision present in the subversion repo\n";
      die;
  }
  
  my $r = $ARGV[0] + 1;
  
  `svnadmin dump /afs/csail/group/vision/app/REPOS/videoIO -r $r:HEAD --incremental | bzip2 > svndump.bz2`;
} else {
  ###### FULL UPLOAD VERSION
  if (@ARGV) {
      print "USAGE:\n";
      print "  mirrorToSourceforge.pl\n";
      die;
  }
  `svnadmin dump /afs/csail/group/vision/app/REPOS/videoIO -r 0:HEAD | bzip2 > svndump.bz2`;
}
  
`scp svndump.bz2 $ENV{USER}\@frs.sourceforge.net:uploads/svndump.bz2`;

###### INSTRUCTIONS
print <<EOM;

Now, you must:
1) Login to the SourceForge.net website.
2) Go to the project summary page (https://www.sf.net/projects/videoio).
3) Click on the 'Admin' link.
4) Click on the 'Subversion' admin page link.
5) Click on the 'migrate' link on the 'Migration Instructions' section of 
   the page.
6) Key in the filename of the archive (svndump.bz2) into the 'Source path' 
EOM
if ($USE_INCREMENTAL) {
  print "7) UN-check the 'Replace' check box in the same column if it's checked.\n";
} else {
  print "7) CHECK the 'Replace' check box in the same column if it's unchecked.\n";
}  
print <<EOM;
8) Leave the 'Destination' field empty.
9) Click on the 'Submit' button.
10) Delete the local svndump.bz2

The migration will be finished within 24 hours. It could be finished in as 
soon as an hour or two, depending on the size of your repository and the 
number of projects queued for migration in front of yours. Returning to the 
page will display whether it completed, failed or is still in queue.
EOM
