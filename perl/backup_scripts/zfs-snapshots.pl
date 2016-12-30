#!/usr/bin/perl
# zfs-snapshots.pl
use warnings;
use strict;
use Time::Piece;
use Time::Seconds;

my $timepiece = Time::Piece->new;
my $date = $timepiece->strftime('%Y%m%d');
my $time = $timepiece->strftime('%H%M%S');

my @datasets = `zfs list -H -o name | grep -v xen`;

Hourly(@datasets);
Daily(@datasets);
Weekly(@datasets);

sub Hourly {

    # Create new snapshot and remove hourly snaps older than 2 days
    for my $ds (@datasets) {
	chomp($ds);
	print "Running hourly snapshot for $ds\n";
	my $zfs_create_hourly = "zfs snapshot $ds\@snapshot_hourly_$date-$time";
	system($zfs_create_hourly);
	my @snapshots = `zfs list -H -o name -t snapshot -S creation | grep ^$ds\@snapshot_hourly | tail -n +48`;
	for my $snap (@snapshots) {
	    chomp($snap);
	    print "Removing $snap\n";
	    my $zfs_remove_hourly = "zfs destroy $snap";
	    system($zfs_remove_hourly);
	}
    }

}

sub Daily {

    # Create new snapshot and remove daily snaps older than 30 days
    for my $ds (@datasets) {
	chomp($ds);
	my $latest_snap = `zfs list -H -t snapshot -o name -S creation | grep ^$ds\@snapshot_daily | head -1`;
	chomp($latest_snap);
	print "Latest daily snap = $latest_snap\n";
	if (grep /$date/, $latest_snap) {
	    print "Snapshot for $date already exists, not creating daily snapshot.\n";
	} else {
	    print "Running daily snapshot for $ds\n";
	    my $zfs_create_daily = "zfs snapshot $ds\@snapshot_daily_$date";
	    system($zfs_create_daily);
	    my @snapshots = `zfs list -H -o name -t snapshot -S creation | grep ^$ds\@snapshot_daily | tail -n +30`;
	    for my $snap (@snapshots) {
		chomp($snap);
		print "Removing $snap\n";
		my $zfs_remove_daily = "zfs destroy $snap";
		system($zfs_remove_daily);
	    }
	}
    }

}

sub Weekly {

    my $day = $timepiece->day;
    my $day_num = $timepiece->day_of_week;
    my $sunday = $timepiece - ($day_num * ONE_DAY);

    unless ($day eq "Sun") { 
    	print "It isn't Sunday, not creating weekly snapshots today!\n";
    	return;
    } else {
	for my $ds (@datasets) {
	    chomp($ds);
	    print "Checking $ds\n";
	    my $latest_snap = `zfs list -H -t snapshot -o name -S creation | grep ^$ds\@snapshot_weekly | head -1`;
	    chomp($latest_snap);
	    print "Latest snap = $latest_snap\n";
	    unless (grep /$sunday->strftime('%Y%m%d')/, $latest_snap) {
	    	print "Running weekly snapshot for $ds\n";
	    	my $zfs_create_weekly = "zfs snapshot $ds\@snapshot_weekly_$date";
	    	system($zfs_create_weekly);
	    	my @snapshots = `zfs list -H -o name -t snapshot -S creation | grep ^$ds\@snapshot_weekly | tail -n +12`;
	    	for my $snap (@snapshots) {
	    	    chomp($snap);
	    	    print "Removing $snap\n";
	    	    my $zfs_remove_daily = "zfs destroy $snap";
		    system($zfs_remove_daily);
	    	}
	    }
    	}
    }

}
