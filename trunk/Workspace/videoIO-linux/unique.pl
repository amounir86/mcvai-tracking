#!/usr/bin/perl

# this script takes the input arguments and removes duplicate arguments
# while preserving argument order (the first instance of an argument
# is retained).
#
# This is a convenience script used by the videoIO makefile.
# 
# Example:
#   shell$ unique.pl a b c b a
#   a b c

my @orig = @ARGV;
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
print join(" ", @pruned)."\n";
