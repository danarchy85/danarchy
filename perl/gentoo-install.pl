#!/usr/bin/perl
use warnings;
use strict;

my %disks;
my $rootdir;

print "Setting date to current UTC...\n";
my $ntpdate = "ntpdate pool.ntp.org";
`$ntpdate`;
my $date = "TZ='US/Pacific' date";
system($date);

sub disks {

        print "Enter device for root
Example: sdc1 sda3 sdb2: ";
	$disks{root} = <>;

	print "Enter device for boot: ";
	$disks{boot} = <>;

	print "Enter device for swap: ";
	$disks{swap} = <>;

	print "Enter device for home: ";
	$disks{home} = <>;

	    print "-------------
Mounts set as: \n
root = /dev/$disks{root}
boot = /dev/$disks{boot}
swap = /dev/$disks{swap}
home = /dev/$disks{home}
-------------\n\n";
	
}

sub mounts {

    print "Set target directory: ";
    $rootdir = <>;
    chomp($rootdir);
    print "Target directory set to: $rootdir\n";

    print "creating $rootdir\n";
    `mkdir $rootdir`;

    my $root = $disks{root};
    chomp($root);
    my $mountroot = "mount /dev/$root $rootdir";
    print "Mounting /dev/$root to $rootdir\n";
    `$mountroot`;

    my $boot = $disks{boot};
    chomp($boot);
    print "Creating $rootdir/boot\n";
    my $mkboot = "mkdir -v $rootdir/boot";
    `$mkboot`;
    my $mountboot = "mount /dev/$boot $rootdir\/boot";
    print "Mounting /dev/$boot to $rootdir/boot\n";
    `$mountboot`;

    my $swap = $disks{swap};
    chomp($swap);
    my $mountswap = "swapon /dev/$swap";
    print "Mounting /dev/$swap as swap\n";
    `$mountswap`;

    my $home = $disks{home};
    chomp($home);
    print "Creating $rootdir/boot\n";
    my $mkhome = "mkdir -v $rootdir/home";
    `$mkhome`;
    my $mounthome = "mount /dev/$home $rootdir\/home";
    print "Mounting /dev/$home to $rootdir/home\n";
    `$mounthome`;

}

sub download {

    print "Are we installing a new stage3 or a stage4 backup?
Enter: stage3 or stage4 \n";
    my $stage = <>;
    if ($stage eq "stage3") {
	print "Enter URL of a stage3.tar.bz2 to download: \n";
	my $url = <>;
	chomp($url);
	my $file = "stage3.tar.bz2";
	my $wget = "wget $url -O $rootdir\/$file";
	`$wget`;
	
	print "Decompressing $file\n";
	my $tar = "tar xvjf $rootdir/$file -C $rootdir/";
	`$tar`;
	
    } else {
	if ($stage eq "stage4") {
	    print "Enter local path of stage4 backup:  ";
	    my $path = <>;
	    my $tar = "tar xvjf $path -C $rootdir/";
	    `$tar`;
	}
    }
    
}

sub chroot {

    print "Mounting additional filesystems: /proc /sys /dev\n";
    my $mountproc = "mount -t proc none $rootdir\/proc";
    my $mountdev = "mount --rbind /dev $rootdir\/dev";
    my $mountsys = "mount --rbind /sys $rootdir\/sys";
    `$mountproc && $mountdev && $mountsys`;

    print "Copying resolve.conf over.\n";
    my $resolve = "cp -v /etc/resolv.conf /mnt/gentoo/etc/";
    `$resolve`;
    
    print "Now entering chroot to $rootdir.
You will need to run the following commands within the chroot environment: 
'env-update ; source /etc/profile'
'emerge --sync; emerge -uDNav --with-bdeps=y \@world`
'emerge -av grub xfsprogs nfs-utils dhcpcd sysklogd dcron mlocate parted app-misc/screen sudo gentoo-sources linux-firmware vim emacs'
'for D in udev sysklogd sshd net.eth0 dcron nfsclient ; do rc-update add \$D default ; done'
Once finished, ctrl+d to exit out and continue with setup.\n";
    my $chroot = "chroot $rootdir /bin/bash";
    system($chroot);
    
}

&disks;
&mounts;
&download;
&chroot;

#my $localhostname = `echo $HOSTNAME`;
#print "Returning to $localhostname...\n";

