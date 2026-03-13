package SequenceDiagram::Parser ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

use SequenceDiagram::AST ;

my %BLOCK_OPS = map { $_ => 1 } qw(
	opt loop par critical break assert neg seq strict
	) ;

# ------------------------------------------------------------------------------

sub new
{
my ($class, $tokens, $source, $debug) = @_ ;

return bless
	{
	tokens     => $tokens,
	source     => $source,
	pos        => 0,
	debug      => $debug,
	last_node  => undef,
	depth      => 0,
	breadcrumb => [],
	statements => [],
	}, $class ;
}

# ------------------------------------------------------------------------------

sub loc
{
my ($self) = @_ ;

my $tok = $self->{tokens}[$self->{pos}] ;
return 'end of input' unless $tok ;
return "line $tok->[2]{line} col $tok->[2]{col}" ;
}

# ------------------------------------------------------------------------------

sub tok_loc
{
my ($self, $tok) = @_ ;

return 'unknown' unless $tok && $tok->[2] ;
return "line $tok->[2]{line} col $tok->[2]{col}" ;
}

# ------------------------------------------------------------------------------

sub source_line
{
my ($self, $line, $col) = @_ ;

my @lines = split /\n/, $self->{source} ;
my $text  = $lines[$line - 1] // '' ;
my $caret = ' ' x ($col - 1) . '^' ;

return ($text, $caret) ;
}

# ------------------------------------------------------------------------------

sub push_rule
{
my ($self, $rule) = @_ ;

push @{$self->{breadcrumb}}, $rule ;
}

# ------------------------------------------------------------------------------

sub pop_rule
{
my ($self) = @_ ;

pop @{$self->{breadcrumb}} ;
}

# ------------------------------------------------------------------------------

sub format_error
{
my ($self, $msg) = @_ ;

my $tok  = $self->peek() ;
my $line = $tok ? $tok->[2]{line} : undef ;
my $col  = $tok ? $tok->[2]{col}  : undef ;

my $out = $msg . ' at ' . $self->loc() . "\n" ;

if (defined $line)
	{
	my ($src, $caret) = $self->source_line($line, $col) ;
	$out .= "  $src\n" ;
	$out .= "  $caret\n" ;
	}

if (@{$self->{breadcrumb}})
	{
	$out .= '  context: ' . join(' > ', @{$self->{breadcrumb}}) . "\n" ;
	}

if ($self->{last_node})
	{
	$out .= '  last parsed: ' . $self->{last_node}{type} . "\n" ;
	}

my @ahead ;
for my $i ($self->{pos} .. $self->{pos} + 2)
	{
	my $t = $self->{tokens}[$i] ;
	push @ahead, $t->[0] . ':"' . $t->[1] . '"' if $t ;
	}

$out .= '  next tokens: ' . join(' ', @ahead) . "\n" if @ahead ;

return $out ;
}

# ------------------------------------------------------------------------------

sub debug_error
{
my ($self, $msg) = @_ ;

return unless $self->{debug}{parser} || $self->{debug}{parser_details} ;

print "\n" ;
print 'ERROR  ' . $self->format_error($msg) ;
}

# ------------------------------------------------------------------------------

sub debug_node
{
my ($self, $node, $first_tok) = @_ ;

return unless $self->{debug}{parser} || $self->{debug}{parser_details} ;

my $loc    = $self->tok_loc($first_tok) ;
my $indent = '  ' x $self->{depth} ;
my $type   = $node->{type} ;

my %summary =
	(
	Interaction => sub
		{
		"src=$_[0]{source} arrow=$_[0]{arrow} dst=$_[0]{target} label=\"$_[0]{label}\""
		},
	Participant  => sub
		{
		"$_[0]{keyword} name=$_[0]{name}"
		. (defined $_[0]{alias}  ? " as=$_[0]{alias}"   : '')
		. ($_[0]{active}         ? ' active'             : '')
		. (defined $_[0]{data}   ? ' [data]'             : '')
		},
	Create       => sub
		{
		"name=$_[0]{name}"
		. (defined $_[0]{type_name} ? " type=$_[0]{type_name}" : '')
		. (defined $_[0]{alias}     ? " as=$_[0]{alias}"       : '')
		. ($_[0]{active}            ? ' active'                 : '')
		},
	Destroy      => sub { "name=$_[0]{name}" },
	Activate     => sub { "name=$_[0]{name}" },
	Deactivate   => sub { "name=$_[0]{name}" },
	State        => sub { "participants=" . join(',', @{$_[0]{participants}}) . " label=\"$_[0]{label}\"" },
	Note         => sub { "participants=" . join(',', @{$_[0]{participants}}) . " label=\"$_[0]{label}\"" },
	Reference    => sub { "participants=" . join(',', @{$_[0]{participants}}) . " label=\"$_[0]{label}\"" },
	Ignore       => sub { "messages=" . join(',', @{$_[0]{messages}}) },
	Consider     => sub { "messages=" . join(',', @{$_[0]{messages}}) },
	Block        => sub
		{
		"op=$_[0]{operator}"
		. (defined $_[0]{label} ? " label=\"$_[0]{label}\"" : '')
		},
	AltBlock     => sub { "branches=" . scalar(@{$_[0]{branches}}) },
	) ;

my $summary = $summary{$type} ? $summary{$type}->($node) : '' ;

print "\n" ;
printf "%s%s  %s  %s\n", $indent, $loc, $type, $summary ;

return unless $self->{debug}{parser_details} ;

my %skip = map { $_ => 1 } qw(type body branches statements) ;

for my $key (sort keys %$node)
	{
	next if $skip{$key} ;
	my $v = $node->{$key} ;
	next unless defined $v ;
	$v = ref($v) eq 'ARRAY' ? '[' . join(', ', @$v) . ']' : $v ;
	printf "%s  %-16s  %s\n", $indent, $key, $v ;
	}
}

# ------------------------------------------------------------------------------

sub debug_block_enter
{
my ($self, $op, $label, $tok) = @_ ;

return unless $self->{debug}{parser} || $self->{debug}{parser_details} ;

my $indent = '  ' x $self->{depth} ;
my $lbl    = defined $label ? " \"$label\"" : '' ;

print "\n" ;
printf "%s%s  ENTER Block  op=%s%s\n", $indent, $self->tok_loc($tok), $op, $lbl ;
}

# ------------------------------------------------------------------------------

sub debug_block_exit
{
my ($self, $op, $count) = @_ ;

return unless $self->{debug}{parser} || $self->{debug}{parser_details} ;

my $indent = '  ' x $self->{depth} ;
printf "%sEXIT  Block  op=%s  statements=%d\n", $indent, $op, $count ;
}

# ------------------------------------------------------------------------------

sub peek
{
my ($self) = @_ ;

return $self->{tokens}[$self->{pos}] ;
}

# ------------------------------------------------------------------------------

sub consume
{
my ($self) = @_ ;

return $self->{tokens}[$self->{pos}++] ;
}

# ------------------------------------------------------------------------------

sub match
{
my ($self, $type, $val) = @_ ;

return undef if $self->{pos} >= @{$self->{tokens}} ;

my $tok = $self->{tokens}[$self->{pos}] ;

if ($tok->[0] eq $type && (!defined $val || lc($tok->[1]) eq lc($val)))
	{
	return $self->consume() ;
	}

return undef ;
}

# ------------------------------------------------------------------------------

sub match_word
{
my ($self) = @_ ;

return $self->match('NAME') // $self->match('QUOTED') ;
}

# ------------------------------------------------------------------------------

sub rest_of_line_after
{
my ($self, $tok) = @_ ;

$self->{source_lines} //= [split /\n/, $self->{source}, -1] ;

my $line_num = $tok->[2]{line} ;
my $col      = $tok->[2]{col} ;
my $line     = $self->{source_lines}[$line_num - 1] // '' ;

my $rest = substr($line, $col) ;
$rest =~ s/#.*$// ;
$rest =~ s/^\s+|\s+$//g ;
$rest =~ s/^"(.*)"$/$1/ ;

while ($self->{pos} < @{$self->{tokens}})
	{
	last if $self->{tokens}[$self->{pos}][2]{line} != $line_num ;
	$self->{pos}++ ;
	}

return $rest ;
}

# ------------------------------------------------------------------------------

sub match_block_label
{
my ($self) = @_ ;

my @parts ;

while (1)
	{
	my $t = $self->peek() or last ;
	last if $t->[0] eq 'BRACE' ;
	last unless $t->[0] eq 'NAME' || $t->[0] eq 'QUOTED' || $t->[0] eq 'RESERVED' ;
	push @parts, $self->consume()->[1] ;
	}

return @parts ? join(' ', @parts) : undef ;
}

# ------------------------------------------------------------------------------

sub expect
{
my ($self, $type, $val) = @_ ;

my $tok = $self->match($type, $val) ;

unless ($tok)
	{
	my $got      = $self->peek() ;
	my $got_str  = $got ? $got->[0] . ' "' . $got->[1] . '"' : 'end of input' ;
	my $want_str = defined $val ? $type . ' "' . $val . '"' : $type ;
	my $msg      = 'Expected ' . $want_str . ' but got ' . $got_str ;
	$self->debug_error($msg) ;
	die $self->format_error($msg) ;
	}

return $tok ;
}

# ------------------------------------------------------------------------------

sub expect_word
{
my ($self) = @_ ;

my $tok = $self->match_word() ;

unless ($tok)
	{
	my $got     = $self->peek() ;
	my $got_str = $got ? $got->[0] . ' "' . $got->[1] . '"' : 'end of input' ;
	my $msg     = 'Expected WORD but got ' . $got_str ;
	$self->debug_error($msg) ;
	die $self->format_error($msg) ;
	}

return $tok ;
}

# ------------------------------------------------------------------------------

sub expect_block_body
{
my ($self) = @_ ;

unless ($self->match('BRACE', '{'))
	{
	my $msg = "Expected '{'" ;
	$self->debug_error($msg) ;
	die $self->format_error($msg) ;
	}

my @statements ;

while (1)
	{
	if ($self->match('BRACE', '}')) { last ; }

	my $t = $self->peek()
		or do
			{
			my $msg = "Unexpected end of input, expected '}'" ;
			$self->debug_error($msg) ;
			die $self->format_error($msg) ;
			} ;

	my $node = $self->parse_statement() ;
	push @statements, $node if $node ;
	}

return \@statements ;
}

# ------------------------------------------------------------------------------

sub parse_participant_options
{
my ($self) = @_ ;

my ($alias, $active, $data) ;

while (1)
	{
	if ($self->match('RESERVED', 'as'))
		{
		$alias = $self->expect_word()->[1] ;
		}
	elsif ($self->match('RESERVED', 'active'))
		{
		$active = 1 ;
		}
	elsif ($self->match('RESERVED', 'data'))
		{
		$data = $self->expect('DATA')->[1] ;
		}
	else
		{
		last ;
		}
	}

return ($alias, $active, $data) ;
}

# ------------------------------------------------------------------------------

sub parse_participant_list
{
my ($self) = @_ ;

my @list ;
my $first = $self->expect_word() ;
push @list, $first->[1] ;

while (1)
	{
	$self->match('COMMA') ;
	my $tok = $self->match_word() or last ;
	push @list, $tok->[1] ;
	}

return \@list ;
}

# ------------------------------------------------------------------------------

sub parse_message_list
{
my ($self) = @_ ;

my @list ;
my $first = $self->expect_word() ;
push @list, $first->[1] ;

while (1)
	{
	$self->match('COMMA') ;
	my $tok = $self->match_word() or last ;
	push @list, $tok->[1] ;
	}

return \@list ;
}

# ------------------------------------------------------------------------------

sub parse_diagram
{
my ($self) = @_ ;

$self->{statements} = [] ;

while ($self->peek())
	{
	my $node = $self->parse_statement() ;
	push @{$self->{statements}}, $node if $node ;
	}

return SequenceDiagram::AST->diagram(statements => $self->{statements}) ;
}

# ------------------------------------------------------------------------------

sub parse_statement
{
my ($self) = @_ ;

my $t = $self->peek() or return undef ;

if ($t->[0] eq 'RESERVED')
	{
	my $kw_tok = $self->consume() ;
	my $kw     = lc($kw_tok->[1]) ;
	my $loc    = $kw_tok->[2] ;

	if ($kw eq 'participant' || $kw eq 'actor')
		{
		$self->push_rule("$kw declaration") ;
		my $name              = $self->expect_word()->[1] ;
		my ($alias, $active, $data) = $self->parse_participant_options() ;
		my $node = SequenceDiagram::AST->participant(
			keyword => $kw,
			name    => $name,
			loc     => $loc,
			alias   => $alias,
			active  => $active,
			data    => $data,
			) ;
		$self->pop_rule() ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'create')
		{
		$self->push_rule('create') ;
		my $name      = $self->expect_word()->[1] ;
		my $type_name = $self->match('COLON') ? $self->expect_word()->[1] : undef ;
		my ($alias, $active, $data) = $self->parse_participant_options() ;
		my $node = SequenceDiagram::AST->create(
			name      => $name,
			type_name => $type_name,
			loc       => $loc,
			alias     => $alias,
			active    => $active,
			data      => $data,
			) ;
		$self->pop_rule() ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'destroy')
		{
		my $name = $self->expect_word()->[1] ;
		my $node = SequenceDiagram::AST->destroy(name => $name, loc => $loc) ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'activate')
		{
		my $name = $self->expect_word()->[1] ;
		my $node = SequenceDiagram::AST->activate(name => $name, loc => $loc) ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'deactivate')
		{
		my $name = $self->expect_word()->[1] ;
		my $node = SequenceDiagram::AST->deactivate(name => $name, loc => $loc) ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'state')
		{
		$self->push_rule('state') ;
		my $participants = $self->parse_participant_list() ;
		my $colon        = $self->expect('COLON') ;
		my $label        = $self->rest_of_line_after($colon) ;
		my $node         = SequenceDiagram::AST->state(
			participants => $participants,
			label        => $label,
			loc          => $loc,
			) ;
		$self->pop_rule() ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'note')
		{
		$self->push_rule('note') ;
		my $participants = $self->parse_participant_list() ;
		my $colon        = $self->expect('COLON') ;
		my $label        = $self->rest_of_line_after($colon) ;
		my $node         = SequenceDiagram::AST->note(
			participants => $participants,
			label        => $label,
			loc          => $loc,
			) ;
		$self->pop_rule() ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'ref')
		{
		$self->push_rule('ref') ;
		my $participants = $self->parse_participant_list() ;
		my $colon        = $self->expect('COLON') ;
		my $label        = $self->rest_of_line_after($colon) ;
		my $node         = SequenceDiagram::AST->reference(
			participants => $participants,
			label        => $label,
			loc          => $loc,
			) ;
		$self->pop_rule() ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'ignore' || $kw eq 'consider')
		{
		$self->push_rule($kw) ;
		my $messages ;

		if ($self->match('BRACE', '{'))
			{
			$messages = $self->parse_message_list() ;
			$self->expect('BRACE', '}') ;
			}
		else
			{
			$self->expect('COLON') ;
			$messages = $self->parse_message_list() ;
			}

		my $node = $kw eq 'ignore'
			? SequenceDiagram::AST->ignore(  messages => $messages, loc => $loc)
			: SequenceDiagram::AST->consider(messages => $messages, loc => $loc) ;
		$self->pop_rule() ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($kw eq 'alt')
		{
		$self->push_rule('alt block') ;
		$self->debug_block_enter('ALT', undef, $kw_tok) ;
		$self->{depth}++ ;

		my $label    = $self->match_block_label() ;
		my $body     = $self->expect_block_body() ;
		my @branches = (SequenceDiagram::AST->alt_branch(
			label => $label,
			body  => $body,
			loc   => $loc,
			)) ;

		while ($self->match('RESERVED', 'else'))
			{
			my $else_label = $self->match_block_label() ;
			my $else_body  = $self->expect_block_body() ;
			push @branches, SequenceDiagram::AST->alt_branch(
				label => $else_label,
				body  => $else_body,
				loc   => $loc,
				) ;
			}

		$self->{depth}-- ;
		$self->debug_block_exit('ALT', scalar @branches) ;
		my $node = SequenceDiagram::AST->alt_block(
			branches => \@branches,
			loc      => $loc,
			) ;
		$self->pop_rule() ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	elsif ($BLOCK_OPS{$kw})
		{
		$self->push_rule("$kw block") ;
		my $label = $self->match_block_label() ;
		$self->debug_block_enter($kw, $label, $kw_tok) ;
		$self->{depth}++ ;
		my $body = $self->expect_block_body() ;
		$self->{depth}-- ;
		$self->debug_block_exit($kw, scalar @$body) ;
		my $node = SequenceDiagram::AST->block(
			operator => uc($kw),
			label    => $label,
			body     => $body,
			loc      => $loc,
			) ;
		$self->pop_rule() ;
		$self->debug_node($node, $kw_tok) ;
		$self->{last_node} = $node ;
		return $node ;
		}
	else
		{
		my $msg = 'Unexpected reserved word "' . $kw . '"' ;
		$self->debug_error($msg) ;
		die $self->format_error($msg) ;
		}
	}
elsif ($t->[0] eq 'NAME' || $t->[0] eq 'QUOTED')
	{
	my $src_tok = $self->consume() ;
	$self->push_rule('interaction (source=' . $src_tok->[1] . ')') ;
	my $arr_tok = $self->expect('ARROW') ;
	my $dst_tok = $self->expect_word() ;
	my $colon   = $self->expect('COLON') ;
	my $label   = $self->rest_of_line_after($colon) ;
	my $node    = SequenceDiagram::AST->interaction(
		source => $src_tok->[1],
		arrow  => $arr_tok->[1],
		target => $dst_tok->[1],
		label  => $label,
		loc    => $src_tok->[2],
		) ;
	$self->pop_rule() ;
	$self->debug_node($node, $src_tok) ;
	$self->{last_node} = $node ;
	return $node ;
	}
else
	{
	my $msg = 'Unexpected token ' . $t->[0] . ' "' . ($t->[1] // '') . '"' ;
	$self->debug_error($msg) ;
	die $self->format_error($msg) ;
	}
}

1 ;
