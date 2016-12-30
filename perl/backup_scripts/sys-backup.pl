#!/usr/bin/perl
use warnings;
use strict;
use POSIX qw(strftime);

my $date = strftime "%Y%m%d", localtime;

my $system = $ARGV[0] || Usage();
chomp($system);
my $file;

my @excludes_main = qw(
.bash_history
/mnt/*
/media/*
/tmp/*
/proc/*
/dev/*
/sys/*
/etc/mtab
/home/*
/usr/portage/*
/usr/src/linux*
);

if ($system eq "server") {
    server();
} else {
    if ($system eq "acerv5") {
	acerv5();
    } else {
	if ($system eq "acers3") {
	    acers3();
	} else {
	    if ($system eq "nuc") {
		nuc();
	    } else {
		Usage();
	    }
	}
    }

}

sub server {

    my @excludes_server = qw(
/backup/*
/server/*
/torrents/*
/mnt/archive/*
/mnt/data/*
);

    # write excludes tmp file
    my $excludes_file = "/tmp/excludes";
    open(my $excludes, ">", $excludes_file);
    print $excludes "$_\n" for @excludes_main;
    print $excludes "$_\n" for @excludes_server;
    close($excludes);

    # set scalars for cmds
    $file = "/backup/system-backups/$system/danarchy-$date-Stable.tar.bz2";
    my $tar = "tar cvjf $file / -X $excludes_file";
    my $boot_mount = "mount -v /boot";
    my $boot_umount = "umount -v /boot";

    # run mount and tar cmds
    print "running: $tar\n";
    system($boot_mount);
    system($tar);
    
    system($boot_umount);
    print "Saved system backup to: $file\n";
    
}

sub acerv5 {

    # write excludes tmp file
    my $excludes_file = "/tmp/excludes";
    open(my $excludes, ">", $excludes_file);
    print $excludes "$_\n" for @excludes_main;
    close($excludes);

    # set scalars for cmds
    $file = "/var/tmp/$system-$date-Stable.tar.bz2";
    my $tar = "tar cvjf $file / -X $excludes_file";
    my $boot_mount = "mount -v /boot";
    my $boot_umount = "umount -v /boot";
    
    # run mount and tar cmds
    print "running: $tar\n";
    system($boot_mount);
    system($tar);
    system($boot_umount);
    print "Saved system backup to: $file\n";
    print "Copying $file to danarchy\n";
    CptoSrv();
    
}

sub acers3 {

    # write excludes tmp file
    my $excludes_file = "/tmp/excludes";
    open(my $excludes, ">", $excludes_file);
    print $excludes "$_\n" for @excludes_main;
    close($excludes);

    # set scalars for cmds
    $file = "/var/tmp/$system-$date-Stable.tar.bz2";
    my $tar = "tar cvjf $file / -X $excludes_file";
    my $boot_mount = "mount -v /boot";
    my $boot_umount = "umount -v /boot";

    # run mount and tar cmds
    print "running: $tar\n";
    system($boot_mount);
    system($tar);
    system($boot_umount);
    
    print "Saved system backup to: $file\n";
    print "Copying $file to danarchy\n";
    CptoSrv();

}

sub nuc {

    # write excludes tmp file
    my $excludes_file = "/tmp/excludes";
    open(my $excludes, ">", $excludes_file);
    print $excludes "$_\n" for @excludes_main;
    close($excludes);

    # set scalars for cmds
    $file = "/var/tmp/$system-$date-Stable.tar.bz2";
    my $tar = "tar cvjf $file / -X $excludes_file";
    my $boot_mount = "mount -v /boot";
    my $boot_umount = "umount -v /boot";

    # run mount and tar cmds
    print "running: $tar\n";
    system($boot_mount);
    system($tar);
    system($boot_umount);
    
    print "Saved system backup to: $file\n";
    print "Copying $file to danarchy\n";
    CptoSrv();

}

sub CptoSrv {

    # check for local server connection
    my $danarchy_local = `host danarchy.local | awk '/has address/ {print}'`;
    my $scp = "sudo -u dan scp $file dan\@danarchy.local:/backup/system-backups/$system/";
    if ($danarchy_local) {
	system($scp);
	print "$file successfully copied to danarchy\n";
    }
    
}

sub Usage {

    print "sys-backup.pl <server, acerv5, or acers3>\n";
    exit;
    
}
