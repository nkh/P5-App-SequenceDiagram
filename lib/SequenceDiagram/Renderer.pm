package SequenceDiagram::Renderer ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

use List::Util qw(max) ;

use SequenceDiagram::Config::Defaults ;

my $MARGIN         = 4 ;
my $LABEL_PAD      = 4 ;
my $LIFELINE_START = 3 ;
my $FIRST_Y        = 5 ;
my $FOOTER_GAP     = 2 ;

my %ARROW_STYLE =
	(
	'->'  => 'solid',
	'-->' => 'dashed',
	'->>' => 'parallel',
	) ;

# ------------------------------------------------------------------------------

sub new
{
my ($class, $ast, $debug, $config) = @_ ;

$config //= {} ;

my $chars = $config->{unicode}
	? SequenceDiagram::Config::Defaults::unicode()
	: SequenceDiagram::Config::Defaults::ascii() ;

if (my $user_chars = $config->{chars})
	{
	$chars = { %$chars, %$user_chars } ;
	}

return bless
	{
	ast          => $ast,
	debug        => $debug,
	participants => {},
	order        => [],
	alias_map    => {},
	color_slots  => $config->{colors} // [],
	color_map    => {},
	colorize     => $config->{color} // 0,
	chars        => $chars,
	config       => $config,
	}, $class ;
}

# ------------------------------------------------------------------------------

sub dbg_node
{
my ($self, $type, $detail) = @_ ;

return unless $self->{debug}{canvas} ;

printf "\ncanvas-node  %-16s  %s\n", $type, ($detail // '') ;
}

# ------------------------------------------------------------------------------

sub register
{
my ($self, $name, $alias) = @_ ;

return if exists $self->{participants}{$name} ;

my $index = scalar @{$self->{order}} ;

$self->{participants}{$name} =
	{
	name  => $name,
	label => $alias // $name,
	index => $index,
	} ;

$self->{alias_map}{$alias} = $name if defined $alias ;

push @{$self->{order}}, $name ;
}

# ------------------------------------------------------------------------------

sub resolve
{
my ($self, $name) = @_ ;

return $self->{alias_map}{$name} // $name ;
}

# ------------------------------------------------------------------------------

sub participant_x
{
my ($self, $name) = @_ ;

my $canonical = $self->resolve($name) ;
my $p         = $self->{participants}{$canonical}
	or die "Unknown participant '$name'\n" ;

return $p->{x} ;
}

# ------------------------------------------------------------------------------

sub color_for
{
my ($self, $name, $field) = @_ ;

return undef unless $self->{colorize} ;

my $canonical = $self->resolve($name) ;
my $p         = $self->{participants}{$canonical} or return undef ;
my $index     = $p->{index} ;
my $config    = $self->{config} ;

if ($config->{config_parser})
	{
	return $config->{config_parser}->color_for($canonical, $index, $field) ;
	}

my $slots = $self->{color_slots} ;
return undef unless @$slots ;

my $slot = $slots->[$index % scalar @$slots] ;
return $slot->{$field} // $slot->{color} ;
}

# ------------------------------------------------------------------------------

sub block_color
{
my ($self, $operator) = @_ ;

return undef unless $self->{colorize} ;

my $config = $self->{config} ;
if ($config->{config_parser})
	{
	return $config->{config_parser}->block_color($operator) ;
	}

my $blocks = $config->{blocks} // SequenceDiagram::Config::Defaults::blocks() ;
return $blocks->{$operator} // $blocks->{default} ;
}

# ------------------------------------------------------------------------------

sub collect_participants
{
my ($self, $statements) = @_ ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;

	if ($type eq 'Participant')
		{
		$self->register($node->{name}, $node->{alias}) ;
		}
	elsif ($type eq 'Create')
		{
		$self->register($node->{name}, $node->{alias}) ;
		$self->{participants}{$node->{name}}{deferred} = 1 ;
		}
	elsif ($type eq 'Interaction')
		{
		my $src = $self->resolve($node->{source}) ;
		my $tgt = $self->resolve($node->{target}) ;
		$self->register($src) unless exists $self->{participants}{$src} ;
		$self->register($tgt) unless exists $self->{participants}{$tgt} ;
		}
	elsif ($type eq 'Block')
		{
		$self->collect_participants($node->{body}) ;
		}
	elsif ($type eq 'AltBlock')
		{
		$self->collect_participants($_->{body}) for @{$node->{branches}} ;
		}
	}
}

# ------------------------------------------------------------------------------

sub collect_interactions
{
my ($self, $statements, $result) = @_ ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;

	if ($type eq 'Interaction')
		{
		push @$result, $node ;
		}
	elsif ($type eq 'Block')
		{
		$self->collect_interactions($node->{body}, $result) ;
		}
	elsif ($type eq 'AltBlock')
		{
		$self->collect_interactions($_->{body}, $result) for @{$node->{branches}} ;
		}
	}
}

# ------------------------------------------------------------------------------

sub compute_layout
{
my ($self) = @_ ;

my @order = @{$self->{order}} ;
my $n     = scalar @order ;

return unless $n ;

my %idx = map { $order[$_] => $_ } 0 .. $#order ;

my @box_half ;
for my $name (@order)
	{
	my $label = $self->{participants}{$name}{label} ;
	my $width = length($label) + 4 ;
	push @box_half, int($width / 2) ;
	}

my @interactions ;
$self->collect_interactions($self->{ast}{statements}, \@interactions) ;

my @x ;
$x[0] = $MARGIN + $box_half[0] ;

for my $i (1 .. $n - 1)
	{
	my $min_x = $x[$i - 1] + $box_half[$i - 1] + $box_half[$i] + $MARGIN ;

	for my $inter (@interactions)
		{
		my $si = $idx{$self->resolve($inter->{source})} ;
		my $ti = $idx{$self->resolve($inter->{target})} ;
		next unless defined $si && defined $ti ;

		my ($li, $ri) = $si < $ti ? ($si, $ti) : ($ti, $si) ;
		next unless $ri == $i ;
		next if $li == $ri ;

		my $required = $x[$li] + length($inter->{label} // '') + $LABEL_PAD * 2 ;
		$min_x       = max($min_x, $required) ;
		}

	$x[$i] = $min_x ;
	}

for my $i (0 .. $#order)
	{
	$self->{participants}{$order[$i]}{x}       = $x[$i] ;
	$self->{participants}{$order[$i]}{box_half} = $box_half[$i] ;
	}
}

# ------------------------------------------------------------------------------

sub count_rows
{
my ($self, $statements) = @_ ;

my $rows = 0 ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;

	if    ($type eq 'Interaction') { $rows += 2 }
	elsif ($type eq 'Create')      { $rows += 4 }
	elsif ($type eq 'Destroy')     { $rows += 2 }
	elsif ($type eq 'State')       { $rows += 2 }
	elsif ($type eq 'Note')        { $rows += 2 }
	elsif ($type eq 'Reference')   { $rows += 2 }
	elsif ($type eq 'Block')
		{
		$rows += 2 ;
		$rows += $self->count_rows($node->{body}) ;
		}
	elsif ($type eq 'AltBlock')
		{
		for my $branch (@{$node->{branches}})
			{
			$rows += 2 ;
			$rows += $self->count_rows($branch->{body}) ;
			}
		}
	}

return $rows ;
}

# ------------------------------------------------------------------------------

sub measure_statements
{
my ($self, $statements, $y_ref, $state) = @_ ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;

	if ($type eq 'Activate')
		{
		my $name = $self->resolve($node->{name}) ;
		push @{$state->{act_stack}{$name}}, $$y_ref ;
		}
	elsif ($type eq 'Deactivate')
		{
		my $name = $self->resolve($node->{name}) ;
		if (@{$state->{act_stack}{$name} // []})
			{
			my $start = pop @{$state->{act_stack}{$name}} ;
			push @{$state->{act_spans}},
				{
				name    => $name,
				start_y => $start,
				end_y   => $$y_ref,
				} ;
			}
		}
	elsif ($type eq 'Create')
		{
		$state->{create_y}{$self->resolve($node->{name})} = $$y_ref ;
		$$y_ref += 4 ;
		}
	elsif ($type eq 'Destroy')
		{
		my $name = $self->resolve($node->{name}) ;

		while (@{$state->{act_stack}{$name} // []})
			{
			my $start = pop @{$state->{act_stack}{$name}} ;
			push @{$state->{act_spans}},
				{
				name    => $name,
				start_y => $start,
				end_y   => $$y_ref,
				} ;
			}

		if ($state->{depth} == 0)
			{
			$state->{destroy_y}{$name} = $$y_ref ;
			}
		else
			{
			$state->{cond_destroy_y}{$name} = $$y_ref ;
			}

		$$y_ref += 2 ;
		}
	elsif ($type eq 'Interaction') { $$y_ref += 2 }
	elsif ($type eq 'State')       { $$y_ref += 2 }
	elsif ($type eq 'Note')        { $$y_ref += 2 }
	elsif ($type eq 'Reference')   { $$y_ref += 2 }
	elsif ($type eq 'Block')
		{
		$$y_ref += 2 ;
		$state->{depth}++ ;
		$self->measure_statements($node->{body}, $y_ref, $state) ;
		$state->{depth}-- ;
		}
	elsif ($type eq 'AltBlock')
		{
		for my $branch (@{$node->{branches}})
			{
			$$y_ref += 2 ;
			$state->{depth}++ ;
			$self->measure_statements($branch->{body}, $y_ref, $state) ;
			$state->{depth}-- ;
			}
		}
	}
}

# ------------------------------------------------------------------------------

sub draw_participant_box
{
my ($self, $canvas, $name, $y) = @_ ;

my $p     = $self->{participants}{$name} ;
my $cx    = $p->{x} ;
my $half  = $p->{box_half} ;
my $color = $self->color_for($name, 'color') ;
my $chars = $self->{chars} ;

my $keyword = $self->{ast} && $self->participant_keyword($name) ;

if ($keyword && $keyword eq 'actor')
	{
	$canvas->draw_actor_box($cx - $half, $y, $p->{label}, $chars, $color) ;
	}
else
	{
	$canvas->draw_box($cx - $half, $y, $p->{label}, $chars, $color) ;
	}
}

# ------------------------------------------------------------------------------

sub participant_keyword
{
my ($self, $name) = @_ ;

for my $node (@{$self->{ast}{statements}})
	{
	if ($node->{type} eq 'Participant' && $node->{name} eq $name)
		{
		return $node->{keyword} ;
		}
	}

return 'participant' ;
}

# ------------------------------------------------------------------------------

sub compute_max_text_width
{
my ($self, $statements, $min_width) = @_ ;

my $max = $min_width ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;

	if ($type eq 'State' || $type eq 'Note' || $type eq 'Reference')
		{
		my $cx    = $self->participant_x($node->{participants}[0]) ;
		my $right = $cx + length($node->{label}) + 4 ;
		$max      = max($max, $right) ;
		}
	elsif ($type eq 'Interaction')
		{
		my $src_x = $self->participant_x($node->{source}) ;
		my $tgt_x = $self->participant_x($node->{target}) ;
		my $right = max($src_x, $tgt_x) + length($node->{label}) + $LABEL_PAD ;
		$max      = max($max, $right) ;
		}
	elsif ($type eq 'Block')
		{
		$max = $self->compute_max_text_width($node->{body}, $max) ;
		}
	elsif ($type eq 'AltBlock')
		{
		$max = $self->compute_max_text_width($_->{body}, $max)
			for @{$node->{branches}} ;
		}
	}

return $max ;
}

# ------------------------------------------------------------------------------

sub render
{
my ($self) = @_ ;

require SequenceDiagram::Canvas ;

$self->collect_participants($self->{ast}{statements}) ;
$self->compute_layout() ;

my @order = @{$self->{order}} ;

my $content_rows = $self->count_rows($self->{ast}{statements}) ;
my $total_height = $FIRST_Y + $content_rows + $FOOTER_GAP ;

my $last_p    = $self->{participants}{$order[-1]} ;
my $min_width = $last_p->{x} + $last_p->{box_half} + $MARGIN ;
my $width     = $self->compute_max_text_width($self->{ast}{statements}, $min_width) ;

my $canvas = SequenceDiagram::Canvas->new($self->{debug}{canvas}, $width, $total_height) ;

my %state =
	(
	act_stack      => {},
	act_spans      => [],
	create_y       => {},
	destroy_y      => {},
	cond_destroy_y => {},
	depth          => 0,
	) ;

my $measure_y = $FIRST_Y ;
$self->measure_statements($self->{ast}{statements}, \$measure_y, \%state) ;

# Close unclosed activation spans at end of diagram
for my $name (keys %{$state{act_stack}})
	{
	while (@{$state{act_stack}{$name}})
		{
		my $start = pop @{$state{act_stack}{$name}} ;
		push @{$state{act_spans}},
			{
			name    => $name,
			start_y => $start,
			end_y   => $measure_y,
			} ;
		}
	}

my $ch = $self->{chars} ;

# 1 — lifelines
for my $name (@order)
	{
	my $p       = $self->{participants}{$name} ;
	my $cx      = $p->{x} ;
	my $start_y = $state{create_y}{$name}
		? $state{create_y}{$name} + 3
		: $LIFELINE_START ;
	my $end_y   = $state{destroy_y}{$name} // $total_height ;
	my $length  = $end_y - $start_y ;
	my $color   = $self->color_for($name, 'lifeline') ;

	$canvas->draw_vertical_line($cx, $start_y, $length, $ch->{lifeline}, $color) if $length > 0 ;
	}

# 2 — activation bars
for my $span (@{$state{act_spans}})
	{
	my $cx     = $self->participant_x($span->{name}) ;
	my $length = $span->{end_y} - $span->{start_y} ;
	my $color  = $self->color_for($span->{name}, 'activebar') ;
	$canvas->draw_vertical_line($cx, $span->{start_y}, $length, $ch->{activation}, $color) if $length > 0 ;
	}

# 3 — participant header boxes
for my $name (@order)
	{
	next if $state{create_y}{$name} ;
	next if $self->{participants}{$name}{deferred} ;
	$self->draw_participant_box($canvas, $name, 0) ;
	}

# 4 — content
my $current_y = $FIRST_Y ;
$self->process_statements($self->{ast}{statements}, $canvas, \$current_y, \%state) ;

return $canvas ;
}

# ------------------------------------------------------------------------------

sub process_statements
{
my ($self, $statements, $canvas, $y_ref, $state) = @_ ;

my $ch = $self->{chars} ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;
	my $y    = $$y_ref ;

	if ($type eq 'Interaction')
		{
		$self->dbg_node('Interaction', "src=$node->{source} dst=$node->{target}") ;

		my $src_x  = $self->participant_x($node->{source}) ;
		my $tgt_x  = $self->participant_x($node->{target}) ;
		my $label  = $node->{label} // '' ;
		my $style  = $ARROW_STYLE{$node->{arrow}} // 'solid' ;
		my $color  = $self->color_for($node->{source}, 'arrow') ;

		if ($src_x == $tgt_x)
			{
			my $hook_w = length($label) + 2 ;
			$canvas->draw_horizontal_line($src_x + 1, $y - 1, $hook_w, undef, $color) ;
			$canvas->write_text($src_x + 1, $y - 1, $label, $color) ;
			$canvas->draw_horizontal_line($src_x + 1, $y,     $hook_w, undef, $color) ;
			$canvas->write_text($src_x,     $y,     '<', $color) ;
			$canvas->write_text($src_x + $hook_w, $y - 1, '+', $color) ;
			$canvas->write_text($src_x + $hook_w, $y,     '+', $color) ;
			}
		else
			{
			my ($left_x, $right_x) = $src_x < $tgt_x
				? ($src_x,  $tgt_x)
				: ($tgt_x,  $src_x) ;
			my $direction = $src_x < $tgt_x ? 'right' : 'left' ;
			my $length    = $right_x - $left_x - 1 ;
			my $label_x   = $left_x + int(($right_x - $left_x - length($label)) / 2) ;

			$canvas->write_text($label_x, $y - 1, $label, $color) ;
			$canvas->draw_horizontal_arrow($left_x + 1, $y, $length - 1, $direction, $style, $ch, $color) ;
			}

		$$y_ref += 2 ;
		}
	elsif ($type eq 'Create')
		{
		$self->dbg_node('Create', "name=$node->{name}") ;
		$self->register($node->{name}, $node->{alias}) ;
		$self->draw_participant_box($canvas, $node->{name}, $y) ;

		my $tgt_name = $self->resolve($node->{name}) ;
		my $tgt_x    = $self->{participants}{$tgt_name}{x} ;
		my $tgt_half = $self->{participants}{$tgt_name}{box_half} ;
		my $best_x   = -1 ;

		for my $pname (@{$self->{order}})
			{
			next if $pname eq $tgt_name ;
			next if $self->{participants}{$pname}{deferred} ;
			my $px = $self->{participants}{$pname}{x} // 0 ;
			$best_x = $px if $px < $tgt_x && $px > $best_x ;
			}

		if ($best_x >= 0)
			{
			my $arrow_tgt = $tgt_x - $tgt_half - 1 ;
			my $arrow_len = $arrow_tgt - $best_x - 1 ;

			if ($arrow_len > 0)
				{
				my $label    = 'create' ;
				my $label_x  = $best_x + int(($arrow_len - length($label)) / 2) + 1 ;
				my $color    = $self->color_for($node->{name}, 'arrow') ;
				$canvas->write_text($label_x, $y + 1, $label, $color) ;
				$canvas->draw_horizontal_arrow($best_x + 1, $y + 2, $arrow_len - 1, 'right', 'dashed', $ch, $color) ;
				}
			}

		$$y_ref += 4 ;
		}
	elsif ($type eq 'Destroy')
		{
		$self->dbg_node('Destroy', "name=$node->{name}") ;
		my $cx    = $self->participant_x($node->{name}) ;
		my $color = $self->color_for($node->{name}, 'destroy') ;
		$canvas->write_text($cx - 1, $y,     $ch->{destroy_tl} . $ch->{destroy_tc} . $ch->{destroy_tr}, $color) ;
		$canvas->write_text($cx - 1, $y + 1, $ch->{destroy_bl} . $ch->{destroy_bc} . $ch->{destroy_br}, $color) ;
		$$y_ref += 2 ;
		}
	elsif ($type eq 'Activate' || $type eq 'Deactivate')
		{
		# Visual drawn in measure pass — no y advance
		}
	elsif ($type eq 'State')
		{
		$self->dbg_node('State', join(',', @{$node->{participants}})) ;
		my $p     = $node->{participants}[0] ;
		my $cx    = $self->participant_x($p) ;
		my $color = $self->color_for($p, 'annotations') ;
		$canvas->write_text($cx, $y, '{' . $node->{label} . '}', $color) ;
		$$y_ref += 2 ;
		}
	elsif ($type eq 'Note')
		{
		$self->dbg_node('Note', join(',', @{$node->{participants}})) ;
		my $p     = $node->{participants}[0] ;
		my $cx    = $self->participant_x($p) ;
		my $color = $self->color_for($p, 'annotations') ;
		$canvas->write_text($cx, $y, '* ' . $node->{label}, $color) ;
		$$y_ref += 2 ;
		}
	elsif ($type eq 'Reference')
		{
		$self->dbg_node('Reference', "label=$node->{label}") ;
		my $p     = $node->{participants}[0] ;
		my $cx    = $self->participant_x($p) ;
		my $color = $self->color_for($p, 'annotations') ;
		$canvas->write_text($cx, $y, 'ref: ' . $node->{label}, $color) ;
		$$y_ref += 2 ;
		}
	elsif ($type eq 'Block')
		{
		$self->dbg_node('Block', "op=$node->{operator}") ;
		my $label  = defined $node->{label} ? ' ' . $node->{label} : '' ;
		my $header = '[' . $node->{operator} . $label . ']' ;
		my $color  = $self->block_color($node->{operator}) ;
		$canvas->write_text(2, $$y_ref, $header, $color) ;
		$$y_ref += 2 ;
		$self->process_statements($node->{body}, $canvas, $y_ref, $state) ;
		}
	elsif ($type eq 'AltBlock')
		{
		$self->dbg_node('AltBlock', '') ;

		for my $branch (@{$node->{branches}})
			{
			my $label  = defined $branch->{label} ? ' ' . $branch->{label} : ' (else)' ;
			my $header = '[ALT' . $label . ']' ;
			my $color  = $self->block_color('alt') ;
			$canvas->write_text(2, $$y_ref, $header, $color) ;
			$$y_ref += 2 ;
			$self->process_statements($branch->{body}, $canvas, $y_ref, $state) ;
			}
		}
	}
}

1 ;
