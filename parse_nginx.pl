#!/usr/bin/perl
use warnings;
use strict;
use JSON;
use Data::Dumper;
use Carp;
use Getopt::Declare;

my $opt = new Getopt::Declare q{
		--json			Output JSON instead of syntax tree.
		-j				[ditto]

		--debug			Output debug info
		-d				[ditto]
		<infile>			Input nginx.conf file
	};

	if (!$opt) {
		print "Err :$!\n";
	}
	#print Dumper(\$opt);

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
			| <server>		<type='server'>
			| <directive>	<type='directive'>
		)
		# <debug:off>

	<rule: comment>
		\# ([^\n]*) \n

	<rule: directive>
		<command=word>  <[arg]>* ** <.ws> (;) <comment>? 

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




my $filename = $opt->{'<infile>'} ||'conf.example';

my $file;
{
	local $/;
	open FILE, '<', $filename
		or die $!;
	$file = <FILE>;
	close FILE;
}

#print $file . "\n\n";
my $tree;
if ($file =~ $grammar && %/) {
	$tree = \%/;
} else {
	print encode_json({error=>'Parse failed -- bad config file?'});
}

#print Dumper(\$tree);
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

if ($opt->{'--json'}) {
	print to_json(\%servers, {utf8=>1, pretty=>1});
} else {
	print Dumper(\%servers);
}
