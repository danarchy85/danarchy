#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use Data::Dumper;

my $date = `date +%Y%m%d`;
chomp($date);

my $dbuser = "mysqlbackup";
my $dbpass = `cat /root/.mysqldbpasswd`;
my $host = "xenmysql";
my $budir = "/backup/website-backups/mysql-backup";

# connect to xenmysql
my $dbh = DBI->connect ("DBI:mysql:host=$host",$dbuser,$dbpass) || die "Failed to connect to MySQL.";
my $sth = $dbh->prepare('show databases');
$sth->execute;

# Repair and backup databases
while (my @Dbs = $sth->fetchrow_array()) {
    for my $db (@Dbs) {
	next if ($db eq 'information_schema');
	next if ($db eq 'mysql');
	next if ($db eq 'performance_schema');
	print "Repairing $db\n";
	my $table_sql = "show tables from $db";
	my $sth_table_sql = $dbh->prepare($table_sql);
	$sth_table_sql->execute();
	while (my $table = $sth_table_sql->fetchrow_array()) {
	    print "Repairing $db.$table\n";
	    my $check_table_sql = "repair table $db.$table";
	    my $sth_check_table = $dbh->prepare($check_table_sql);
	    $sth_check_table->execute();
	}
	my $backup_cmd = "mysqldump -v -h $host -u $dbuser -p$dbpass $db | bzip2 > $budir/$db-mysqldump-$date.sql.bz2";
	system($backup_cmd);
    }
}
