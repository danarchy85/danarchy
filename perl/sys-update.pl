#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

my ($host, $quiet, $skip_rsync, $rsync_options);
my $path = "/usr/portage/";

my %server_vars = (
    server_hostname => 'server_hostname',
    server_domain   => 'server_domain',
    server_lan_ip   => 'server_lan_ip',
    server_user     => 'server_user',
    );

GetOptions(
    'quiet' => \$quiet,
    'skip_rsync' => \$skip_rsync
);

location();

sub location {

    # Check current IP to determine if on home LAN
    my $ip_cmd = "ip addr | awk '/inet 10.0/ {print\$2}'";
    my $ip = `$ip_cmd`;
    chomp($ip);
#    return print "Could not find an IP.\n" unless $ip;
#    print "Local IP : $ip\n";

    if ( $ip =~ /^10.0.1/ ) {
	$host = $server_vars{'server_lan_ip'}
    } else {
	$host = $server_vars{'server_domain'}
    }

    
    unless ($skip_rsync) { print "Rsyncing repo from : $host\n"; rsync(); };
    emerge();
    
}

sub rsync {

    my $options = "";
    my $verbose = "--verbose";
    my $user = $server_vars{'server_user'}
    if ($quiet) {
	$rsync_options = "--recursive --links --perms --times --devices --delete --timeout=300 --exclude=distfiles/";
    } else {
	$rsync_options = "--verbose --recursive --links --perms --times --devices --delete --timeout=300 --exclude=distfiles/";
    }

    print "Rsyncing portage repo from $host to $path\n";
    my $rsync = "sudo rsync $rsync_options $user\@$host:$path $path";
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
