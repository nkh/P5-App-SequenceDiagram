package SequenceDiagram::Lexer ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

my %RESERVED = map { $_ => 1 } qw(
	participant actor as active data
	activate deactivate
	create destroy
	state note ref
	ignore consider
	alt opt loop par critical break assert neg seq strict
	else
	) ;

# Token types produced:
#   RESERVED  — a reserved keyword
#   NAME      — an unquoted non-reserved identifier (letters, digits, underscores, dashes)
#   QUOTED    — a single- or double-quoted string (value excludes quotes)
#   ARROW     — -> | --> | ->>
#   BRACE     — { or }
#   COLON     — :
#   COMMA     — ,
#   CHAR      — any other single character (consumed by rest_of_line_after in Parser)
#   DATA      — raw content of a data block (balanced braces, value excludes outer braces)

# ------------------------------------------------------------------------------

sub new
{
my ($class, $text, $debug) = @_ ;

my @line_offsets = (0) ;
while ($text =~ /\n/g) { push @line_offsets, pos($text) ; }

return bless
	{
	text         => $text,
	debug        => $debug,
	line_offsets => \@line_offsets,
	}, $class ;
}

# ------------------------------------------------------------------------------

sub loc
{
my ($self, $offset) = @_ ;

my @lo   = @{$self->{line_offsets}} ;
my $line = 1 ;

for my $i (1 .. $#lo)
	{
	last if $lo[$i] > $offset ;
	$line = $i + 1 ;
	}

my $col = $offset - $lo[$line - 1] + 1 ;

return { line => $line, col => $col } ;
}

# ------------------------------------------------------------------------------

sub scan_data_block
{
my ($self, $text_ref, $loc) = @_ ;

my $depth   = 1 ;
my $content = '' ;

while (pos($$text_ref) < length($$text_ref))
	{
	if    ($$text_ref =~ /\G([^{}]+)/gc) { $content .= $1 ; }
	elsif ($$text_ref =~ /\G\{/gc)       { $depth++ ; $content .= '{' ; }
	elsif ($$text_ref =~ /\G\}/gc)
		{
		$depth-- ;
		last if $depth == 0 ;
		$content .= '}' ;
		}
	}

die "Unterminated data block at line $loc->{line} col $loc->{col}\n"
	if $depth > 0 ;

return $content ;
}

# ------------------------------------------------------------------------------

sub tokenize
{
my ($self) = @_ ;

my $text       = $self->{text} ;
my $debug      = $self->{debug} ;
my @tokens ;
my $after_data = 0 ;

while ($text =~ /\s*+/g)
	{
	if    ($text =~ /\G#[^\n]*/gc)      { next ; }
	elsif (pos($text) == length($text)) { last ; }

	my $start = pos($text) ;
	my $loc   = $self->loc($start) ;

	my ($type, $val) ;

	if ($after_data && $text =~ /\G\{/gc)
		{
		$val  = $self->scan_data_block(\$text, $loc) ;
		$type = 'DATA' ;
		}
	elsif ($text =~ /\G"((?:[^"\\]|\\.)*)"/gc) { ($type, $val) = ('QUOTED',   $1) ; }
	elsif ($text =~ /\G'((?:[^'\\]|\\.)*)'/gc) { ($type, $val) = ('QUOTED',   $1) ; }
	elsif ($text =~ /\G(->>)/gc)                { ($type, $val) = ('ARROW',    $1) ; }
	elsif ($text =~ /\G(-->)/gc)                { ($type, $val) = ('ARROW',    $1) ; }
	elsif ($text =~ /\G(->)/gc)                 { ($type, $val) = ('ARROW',    $1) ; }
	elsif ($text =~ /\G([a-zA-Z_][\w-]*)/gc)
		{
		$type = $RESERVED{lc $1} ? 'RESERVED' : 'NAME' ;
		$val  = $1 ;
		}
	elsif ($text =~ /\G(\{|\})/gc) { ($type, $val) = ('BRACE', $1) ; }
	elsif ($text =~ /\G(:)/gc)     { ($type, $val) = ('COLON', $1) ; }
	elsif ($text =~ /\G(,)/gc)     { ($type, $val) = ('COMMA', $1) ; }
	elsif ($text =~ /\G(.)/gcs)    { ($type, $val) = ('CHAR',  $1) ; }

	$after_data = ($type eq 'RESERVED' && lc($val) eq 'data') ;

	push @tokens, [ $type, $val, $loc ] ;

	printf "token  %4d:%-4d  %-10s  %s\n",
		$loc->{line}, $loc->{col}, $type, $val
		if $debug ;
	}

return \@tokens ;
}

1 ;
