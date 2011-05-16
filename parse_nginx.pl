#!/usr/bin/perl
use warnings;
use strict;
use Regexp::Grammars;
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

my $grammar = qr@
	<nocontext:>
	#<debug:on>

	<[server]>*

	<rule: server>
		<[comment]>* (server) <block>

	<rule: block>
		\{ <[line]>* ** (;) <minimize:> \} 

	<rule: line>
		(^)
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
		\# ([^\n]*) (?: $ )

	<rule: directive>
		<command=word>  <[arg]>* ** <.ws> <minimize:> (;) <comment>? 

	<rule: if>
		<[comment]>* if \( <[condition]>* \) <block>

	<rule: location>
		<[comment]>* (location) <cop>? <locarg> <block>

	<rule: rewrite>
		(rewrite) (.+?) <.eol>

	<rule: condition>	<[opd]> (<cop> <[opd]>)?

	<rule: opd>		!? -?<word>

	<rule: cop>		\|\| | \&\& | != | ==? | <<? | >>? | =~ | \+ | - | ~
	<rule: locarg>	[^{\s]+?
	<token: arg>		[a-zA-Z0-9_\$/\.:+*\\^(){}\[\]=-]+

	<rule: word>	\$?\w+

	<rule: eol>		\n+|;
@xms;




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
	if ($opt->{'--json'}) {
		print encode_json(\%/);
	} else {
		print Dumper(\%/);
	}
} else {
	print encode_json({error=>'Parse failed -- bad config file?'});
}



=pod COMMENTED

SERVER: for (@{$tree->{server}} ) {
	my $lines = $_->{block}->{line};
	my $server = {};
	$server->{directives} = [];
	for my $line (@$lines) {
		my $type = (keys %$line)[0];
		if ($type eq 'directive') {
			push @{$server->{directives}}, $line->{$type};
		}
	}
	print Dumper(\$server);
}

=cut
