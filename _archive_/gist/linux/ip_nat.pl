#!/usr/bin/perl

package main;

use strict;
use warnings;

no if ($] >= 5.018), 'warnings' => 'experimental';

my ($cmds, $cmd) = ({
    init => \&init,
    add => \&add,
    del => \&del,
    stats => \&stats,
    purge => \&purge,
    rebalance => \&rebalance
}, shift);

$cmds->{$cmd} or die "Command not found: $cmd";
$cmds->{$cmd}->();

sub init {
    my ($cnt) = @ARGV;
    die "No count tables" if not $cnt;

    my @exists = `ipset list -o save | grep 'create' | egrep -o 'nat_([0-9]+)'`;
    chomp(@exists);

    my %tables;

    for my $i (@exists) {
	$tables{$i} = 1;
    }

    for my $i (0..$cnt-1) {
	delete $tables{"nat_$i"};
	next if "nat_$i" ~~ @exists;
	print `ipset create nat_$i iphash`;
    }

    if (keys %tables > 0) {
	foreach my $tbl (keys %tables) {
	    $cmds->{rebalance}->($tbl);
	}
    }

    $cmds->{rebalance}->() if (keys @ARGV > 1 && $ARGV[1] eq 'rebalance');
}

sub add {
    my ($ip_int, ($ip_ext)) = (shift, @ARGV);
    my $ip = (not $ip_int)? $ip_ext : $ip_int;
    die "No ip address" if not $ip;

    $cmds->{del}->($ip);

    my @usage = `ipset list -o save | egrep -o 'nat_([0-9]+)' | sort | uniq -c`;
    chomp(@usage);

    my %pool;
    for my $line (@usage) {
	my ($count, $key) = split(" ", $line);
	$pool{$key} = $count;
    }

    foreach my $key (sort { $pool{$a} <=> $pool{$b} } keys %pool){
	print `ipset test $key $ip 2> /dev/null || ipset add $key $ip`;
	last;
    }
}

sub del {
    my ($ip_int, ($ip_ext)) = (shift, @ARGV);
    my $ip = (not $ip_int)? $ip_ext : $ip_int;
    die "No ip address" if not $ip;

    my @exists = `ipset list -o save | grep 'create' | egrep -o 'nat_([0-9]+)'`;
    chomp(@exists);

    for my $set (@exists) {
	print `ipset test $set $ip 2> /dev/null  && ipset del $set $ip`;
    }
}

sub rebalance {
    my $table = shift;
    my @addrs;

    if (not $table) {
	@addrs = `ipset list -o save  | grep 'add' | egrep 'nat_([0-9]+)' | egrep -o '([0-9]+)\\.([0-9]+)\\.([0-9]+)\\.([0-9]+)'`;
    } else {
	@addrs = `ipset list -o save $table | grep 'add' | egrep -o '([0-9]+)\\.([0-9]+)\\.([0-9]+)\\.([0-9]+)'`;
	print `ipset destroy $table`;
    }

    chomp(@addrs);

    for my $ip (@addrs) {
	$cmds->{add}->($ip);
    }
}

sub stats {
    my (@info, $total) = (`ipset list -o save | egrep -o 'nat_([0-9]+)' | sort | uniq -c`, 0);
    chomp(@info);

    for my $line (@info) {
	next if not $line;
	my ($cnt, $table) = split(" ", $line);
	printf "Table %s has %s entries\n", $table, $cnt-1;
	$total += ($cnt-1);
    }

    printf "Total %s entries\n", $total;
}

sub purge {
    print `ipset list -o save | egrep -o 'nat_([0-9]+)' | sort | uniq | xargs -I {} ipset flush {}`;
}
