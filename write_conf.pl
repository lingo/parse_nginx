#!/usr/bin/perl

=head1 SYNOPSIS

This program attempts to read a parse tree in Perl Storable format, and writes
an nginx-config file from that tree.

=cut

use warnings;
use strict;
use Data::Dumper;
use Carp;
use Storable qw/thaw retrieve/;

my $data;
{ local $/; $data = <>; }

my $tree = thaw($data);
#print Dumper(\$tree);
write_file(\*STDOUT, $tree);

my $iLevel = 0;
my $indent = '';

sub pad {
	my ($file) = @_;
	my $indent = $iLevel ? "\t" x $iLevel : '';
	print $file $indent;
}

sub write_directive {
	my ($file, $item) = @_;
	print $file $item->{command} if $item->{command};
	print $file ' ', join(' ', @{$item->{arg}}) if $item->{arg};
	print $file ' ', $item->{comment} if $item->{comment};
	print $file ";\n";
}

sub write_rewrite {
	my ($file, $item) = @_;
	print $file $item;
}

sub write_comment {
	my ($file, $item) = @_;
	print $file $item;
}

sub write_line {
	my ($file, $item) = @_;
	pad($file);
	my $sub = 'write_' . $item->{type};
	{
		no strict 'refs';
		&$sub($file, $item->{$item->{type}});
	}
}

sub write_location {
	my ($file, $item) = @_;
	print "\n";
	pad $file;
	print $file "location ";
	print $file $item->{op}, ' ' if $item->{op};
	print $file $item->{where}, ' ' if $item->{where};
	write_block($file, $item->{block});
}

sub write_if {
	my ($file, $item) = @_;
	print "\n";
	pad $file;
	print $file "if (", join(' ', @{$item->{condition}->{opd}}) , ') ';
	write_block($file, $item->{block});
}


sub write_server {
	my ($file, $item) = @_;
	for my $comm (@{$item->{comment}}) {
		write_comment($comm);
	}
	pad($file);
	print "\nserver ";
	write_block($file, $item->{block});
}

sub write_block {
	my ($file, $item) = @_;
	print $file "{\n";
	++ $iLevel;
	for my $line (@{$item->{line}}) {
		write_line($file, $line);
	}
	-- $iLevel;
	pad $file;
	print $file "}\n\n";
}

sub write_topblock {
	my ($file, $item) = @_;
	my $type = (keys %$item)[0];
	my $sub = 'write_' . $type;
	{
		no strict 'refs';
		&$sub($file, $item->{$type});
	}
}

sub write_file {
	my ($file, $item) = @_;
	$item = $item->{file};
	for my $top (@{$item->{topblock}}) {
		write_topblock($file, $top);
	}
}

