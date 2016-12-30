#!/usr/bin/perl
use warnings;
use strict;

my $backupdir = "/backup/xen-backup";
my @XenGuests = `xl list | awk '!/Name/ && !/Domain-0/ {print\$1}'`;

for my $xenguest (@XenGuests) {
    chomp($xenguest);
    my $rsync = "rsync -Hazu --delete root\@$xenguest:/home/ $backupdir/$xenguest/";
    print "rsyncing $xenguest to $backupdir/$xenguest.";
    system($rsync);
}
