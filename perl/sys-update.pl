#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

my $quiet;
my $skip_rsync;

GetOptions(
    'quiet' => \$quiet,
    'skip_rsync' => \$skip_rsync
);

my $rsync_options;
my $path = "/usr/portage/";
my $host;

location();

sub location {

    # Check current IP to determine if on home LAN
    my $ip_cmd = "ip addr | awk '/inet 10.0/ {print\$2}'";
    my $ip = `$ip_cmd`;
    chomp($ip);
#    return print "Could not find an IP.\n" unless $ip;
#    print "Local IP : $ip\n";

    if ( $ip =~ /^10.0.1/ ) {
	print "Rsyncing repo from : 10.0.1.13\n";
	$host = "10.0.1.13";
    } else {
	print "Rsyncing repo from : danarchy.me\n";
	$host = "danarchy.me";
    }
    
    unless ($skip_rsync) { rsync() };
    emerge();
    
}

sub rsync {

    my $options = "";
    my $verbose = "--verbose";
    if ($quiet) {
	$rsync_options = "--recursive --links --perms --times --devices --delete --timeout=300 --exclude=distfiles/";
    } else {
	$rsync_options = "--verbose --recursive --links --perms --times --devices --delete --timeout=300 --exclude=distfiles/";
    }

    print "Rsyncing portage repo from $host to $path\n";
    my $rsync = "sudo rsync $rsync_options dan\@$host:$path $path";
    system($rsync);
    return;
    
}

sub emerge {

    print "Emerging Updates\n";
    if ($quiet) {
	my $update = "sudo emerge --update --deep --newuse --ask --with-bdeps=y \@world";
	system($update);
    } else {
	my $update = "sudo emerge --update --deep --newuse --ask --verbose --with-bdeps=y \@world";
	system($update);
    }
    
    print "Cleaning up dependencies\n";
    if ($quiet) {
	my $depclean = "sudo emerge --ask --depclean";
	system($depclean);
    } else {
	my $depclean = "sudo emerge --ask --verbose --depclean";
	system($depclean);
    }

}
