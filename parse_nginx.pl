#!/usr/bin/perl

=head1 SYNOPSIS

This program parses an nginx configuration file (as found in sites-enabled) and
produces a parse_tree via Data::Dumper. Output can also be in Perl Storable
format, or JSON.

=cut


use warnings;
use strict;
use JSON;
use Data::Dumper;
use Carp;
use Getopt::Declare;
use Storable qw/nfreeze/;

our %flags = (
	json	=> 0,
	debug	=> 0,
	freeze	=> 0,
);

my $opt = new Getopt::Declare q/
            --json      	Output JSON instead of syntax tree.
								{ our %flags; $flags{json} = 1; }
            -j          	[ditto]
           
            --debug     	Output debug info
								{ our %flags; $flags{debug} = 1; }
            -d          	[ditto]

            --freeze     	Output Storable frozen data
								{ our %flags; $flags{freeze} = 1; }
            -f          	[ditto]
	/;

	if (!$opt) {
		print "Err :$!\n";
	}
	#print Dumper(\%flags);



# This is the core of the program; a recursive-descent grammar.
my $grammar = do {
	use Regexp::Grammars;
	qr@
	<nocontext:>
	#<debug:on>

	<file>

	<rule: file> (<[topblock]> <[comment]>*)+ $

	<rule: topblock>
		<server> | <upstream>

	<rule: upstream>
		( (upstream) | <[comment]>+ (upstream) ) <name=word> <block>

	<rule: server>
		( (server) | <[comment]>+ (server) ) <block>

	<rule: block>
		\{ <[line]>* ** (;) <minimize:> \} 

	<rule: line>
		#<debug:step>
		( 
			  <comment> 	<type='comment'>
			| <rewrite> 	<type='rewrite'>
			| <if>			<type='if'>
			| <location>	<type='location'>
			# | <server>		<type='server'>
			| <directive>	<type='directive'>
		)
		# <debug:off>

	<rule: comment>
		\# ([^\n]*) (?:\n)

	<rule: directive>
		<command=word>  <[arg]>* ** <.ws> (;)([ \t]*)<comment>? 

	<rule: if>
		((if) | <[comment]>+ (if)) \( <condition> \) <block>

	<rule: location>
		((location) | <[comment]>+ (location))  <op=cop>? <where=locarg> <block>

	<rule: rewrite>
		(rewrite) (.+?) \n

	<rule: andor>	(\&\&) | (\|\|)
	<rule: condition>	(<[opd]> (<[cop]> <[opd]>)?)+

	<rule: opd>		(\!? \-? \$? \w+)

	<rule: cop>		\|\| | \&\& | != | ==? | <<? | >>? | =~ | \+ | - | ~

	<rule: locarg>	[^{\s]+?

	<token: arg>	[a-zA-Z0-9_\$/\.:+*\\^(){}\[\]=\'\"-]+

	<rule: word>	\$?\w+
	@xs;
};




# Read filename from commandline
my $filename = $ARGV[0] ||'conf.example';

# Slurp input file
my $file;
{
	local $/;
	open FILE, '<', $filename
		or die $!;
	$file = <FILE>;
	close FILE;
}

my $tree;
if ($file =~ $grammar && %/) {
	$tree = \%/;
} else {
	my $err = 'Parse failed -- bad config file?';
	if ($flags{json}) {
		$err = encode_json({error => $err});
	}
	print $err;
	exit -1;
}

if ($flags{debug}) {
	print Dumper(\$tree);
	exit 1;
} elsif($flags{freeze}) {
	print nfreeze($tree);
	exit 2;
}

$tree = $tree->{file};

my %servers;

SERVER: for (@{$tree->{topblock}} ) {
	my $type = (keys %$_)[0];
	next unless $type eq 'server';
	my $server = {};
	my $lines = $_->{server}->{block}->{line};

	my @directives = grep{ $_->{type} eq 'directive' } @$lines;
	my @name = grep { $_->{directive}->{command} eq 'server_name' } @directives;
	$server->{name} = $name[0]->{directive}->{arg}->[0];
	my @root = grep { $_->{directive}->{command} eq 'root' } @directives;
	if (@root) {
		$server->{root} = $root[0]->{directive}->{arg}->[0];
	}
	$server->{data} = $lines;
	$server->{dirmap} = {map { $_->{directive}->{command} => $_->{directive} } @directives};
	$servers{$server->{name}} = $server;
}

if ($flags{json}) {
	print to_json(\%servers, {utf8=>1, pretty=>1});
} else {
	print Dumper(\%servers);
}
