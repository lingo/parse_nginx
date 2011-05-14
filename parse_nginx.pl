#!/usr/bin/perl
use warnings;
use strict;
use Regexp::Grammars;
use Data::Dumper;

my $grammar = qr@
    <logfile: parser_log > 
	<nocontext:>

	<[server]>*

	<rule: line>
		<comment>
		| <rewrite>
		| <if>
		| <location>
		| <server>
		| <directive>
	
	<rule: directive>
		<word>  <[arg]>* <comment>? (;) 
		#<type={'directive'}>


	<rule: server>	<[comment]>* server <block>

	<rule: if>
		if \( <[condition]>* \) <block>
		#<type={'if'}>

	<rule: location>
		location <cop> <locarg> <block>
		#<type={'location'}>


	<rule: rewrite>
		rewrite (.+?) <.eol>
		#<type={'rewrite'}>


	<rule: block>		\{ <[line]>* ** (;) \}

	<rule: condition>	<[opd]> (<cop> <[opd]>)?

	<rule: opd>		!? -?<word>
	<rule: cop>		\|\| | \&\& | != | ==? | <<? | >>? | =~ | \+ | - | ~
	<rule: locarg>	[^{\s]+?
	<rule: arg>		[^\s;\n]+
	<rule: word>	\$?\w+

	<rule: comment>
		<ws: ([ \t]+)* >
		\# ([^\n]*) \n

	<rule: eol>		\n+|;
@xs;


my $filename = 'conf.example';
if ($ARGV[0]) {
	$filename = $ARGV[0];
}

my $file;
{
	local $/;
	open FILE, '<', $filename
		or die $!;
	$file = <FILE>;
	close FILE;
}

#print $file . "\n\n";
if ($file =~ $grammar) {
	my $tree = \%/;
	filter_tree($tree);
	print Dumper(\%/);
}


sub filter_tree {
	my $tree = shift or return;

	for (keys %$tree) {
		if (ref $tree->{$_} eq 'HASH') {
			print "Descending into $_\n";
			filter_tree($tree->{$_});
		} elsif (ref $tree->{$_} eq 'ARRAY') {
			my $i;
			for ($i = 0; $i < scalar @{$tree->{$_}}; $i++) {
				if (ref @{$tree->{$_}}[$i] eq 'HASH') {
					filter_tree(@{$tree->{$_}}[$i]);
				}
			}
		}
	}
}
