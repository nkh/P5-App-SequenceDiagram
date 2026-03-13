package SequenceDiagram::SVGRenderer ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

use SequenceDiagram::Renderer ;
use parent -norequire, 'SequenceDiagram::Renderer' ;

use List::Util qw(max) ;

use SequenceDiagram::Config::Defaults ;

# Layout constants — mirror Renderer.pm
my $MARGIN         = 4 ;
my $LIFELINE_START = 3 ;
my $FIRST_Y        = 5 ;
my $FOOTER_GAP     = 2 ;

my %ARROW_STYLE =
	(
	'->'  => 'solid',
	'-->' => 'dashed',
	'->>' => 'parallel',
	) ;

my %ANSI_CSS =
	(
	black          => '#1a202c',
	red            => '#c53030',
	green          => '#276749',
	yellow         => '#b7791f',
	blue           => '#2b6cb0',
	magenta        => '#6b46c1',
	cyan           => '#2c7a7b',
	white          => '#cbd5e0',
	bright_black   => '#718096',
	bright_red     => '#fc8181',
	bright_green   => '#68d391',
	bright_yellow  => '#faf089',
	bright_blue    => '#63b3ed',
	bright_magenta => '#b794f4',
	bright_cyan    => '#76e4f7',
	bright_white   => '#f7fafc',
	) ;


# ------------------------------------------------------------------------------

sub new
{
my ($class, $ast, $debug, $config) = @_ ;

$config //= {} ;

my $svg_defaults = SequenceDiagram::Config::Defaults::svg() ;
my $svg_user     = $config->{config_parser} ? $config->{config_parser}->svg() : {} ;
my %G            = (%$svg_defaults, %$svg_user) ;

return bless
	{
	ast          => $ast,
	debug        => $debug,
	participants => {},
	order        => [],
	alias_map    => {},
	color_slots  => $config->{colors} // [],
	colorize     => $config->{color} // 0,
	chars        => SequenceDiagram::Config::Defaults::ascii(),
	config       => $config,
	G            => \%G,
	}, $class ;
}

# ------------------------------------------------------------------------------

sub geometry
{
my ($self) = @_ ;

return $self->{G} ;
}

# ------------------------------------------------------------------------------

sub css_color
{
my ($self, $name, $field) = @_ ;

return undef unless $self->{colorize} ;

my $ansi = $self->color_for($name, $field) ;
return undef unless defined $ansi ;

$ansi =~ s/\s+on_\S+.*//i ;
$ansi =~ s/^\s+|\s+$//g ;

return $ANSI_CSS{lc $ansi} ;
}

# ------------------------------------------------------------------------------

sub css_block_color
{
my ($self, $operator) = @_ ;

return undef unless $self->{colorize} ;

my $ansi = $self->block_color($operator) ;
return undef unless defined $ansi ;

$ansi =~ s/\s+on_\S+.*//i ;
$ansi =~ s/^\s+|\s+$//g ;

return $ANSI_CSS{lc $ansi} ;
}

# ------------------------------------------------------------------------------

sub esc
{
my ($self, $text) = @_ ;

$text =~ s/&/&amp;/g ;
$text =~ s/</&lt;/g ;
$text =~ s/>/&gt;/g ;
$text =~ s/"/&quot;/g ;

return $text ;
}

# ------------------------------------------------------------------------------

sub svg_defs
{
my ($self) = @_ ;

my $G   = $self->geometry() ;
my $ah  = $G->{arrowhead_size} ;
my $ah2 = $ah / 2 ;
my $c   = $G->{arrow} ;

return <<"DEFS" ;
  <defs>
    <marker id="ah-solid" markerWidth="$ah" markerHeight="$ah" refX="$ah" refY="$ah2" orient="auto">
      <path d="M0,0 L$ah,$ah2 L0,$ah z" fill="$c"/>
    </marker>
    <marker id="ah-dashed" markerWidth="$ah" markerHeight="$ah" refX="$ah" refY="$ah2" orient="auto">
      <path d="M0,0 L$ah,$ah2 L0,$ah z" fill="$c"/>
    </marker>
    <marker id="ah-parallel" markerWidth="$ah" markerHeight="$ah" refX="$ah" refY="$ah2" orient="auto">
      <path d="M0,0 L$ah,$ah2 L0,$ah" fill="none" stroke="$c" stroke-width="1.5"/>
    </marker>
  </defs>
DEFS
}

# ------------------------------------------------------------------------------

sub svg_participant_box
{
my ($self, $name, $grid_y) = @_ ;

my $G      = $self->geometry() ;
my $CW     = $G->{col_width} ;
my $RH     = $G->{row_height} ;
my $BOX_R  = $G->{box_radius} ;
my $FONT   = $G->{font_family} ;
my $FONT_SZ = $G->{font_size} ;

my $p      = $self->{participants}{$name} ;
my $label  = $p->{label} ;
my $cx     = $p->{x} * $CW ;
my $bw     = (length($label) + 4) * $CW ;
my $bh     = 3 * $RH ;
my $bx     = $cx - $bw / 2 ;
my $by     = $grid_y * $RH ;
my $ty     = $by + $bh / 2 + $FONT_SZ * 0.38 ;

my $stroke = $self->css_color($name, 'color') // $G->{participant_stroke} ;
my $fill   = $G->{participant_fill} ;
my $tcolor = $self->css_color($name, 'color') // $G->{participant_text} ;
my $esc    = $self->esc($label) ;
my $r      = $BOX_R ;

return
	(
	qq{  <rect x="$bx" y="$by" width="$bw" height="$bh" rx="$r" ry="$r" fill="$fill" stroke="$stroke" stroke-width="1.5"/>},
	qq{  <text x="$cx" y="$ty" text-anchor="middle" font-family="$FONT" font-size="$FONT_SZ" fill="$tcolor">$esc</text>},
	) ;
}

# ------------------------------------------------------------------------------

sub svg_arrow_line
{
my ($self, $x1, $y, $x2, $direction, $style, $color) = @_ ;

my $G  = $self->geometry() ;
my $AH = $G->{arrowhead_size} ;

$color //= $G->{arrow} ;

my $dash      = $style eq 'dashed' ? ' stroke-dasharray="6,4"' : '' ;
my $marker_id = $style eq 'parallel' ? 'ah-parallel'
	: $style eq 'dashed'   ? 'ah-dashed'
	: 'ah-solid' ;

my ($lx1, $lx2) = $direction eq 'right'
	? ($x1, $x2 - $AH + 1)
	: ($x1, $x2 + $AH - 1) ;

return qq{  <line x1="$lx1" y1="$y" x2="$lx2" y2="$y" stroke="$color" stroke-width="1.5"$dash marker-end="url(#$marker_id)"/>} ;
}

# ------------------------------------------------------------------------------

sub svg_self_arrow
{
my ($self, $cx, $ay, $label, $color, $layers) = @_ ;

my $G      = $self->geometry() ;
my $RH     = $G->{row_height} ;
my $AH     = $G->{arrowhead_size} ;
my $SELF_W = $G->{self_arrow_width} ;
my $FONT   = $G->{font_family} ;
my $FONT_SZ = $G->{font_size} ;

$color //= $G->{arrow} ;

my $x2  = $cx + $SELF_W ;
my $y1  = $ay - int($RH * 0.35) ;
my $y2  = $ay + int($RH * 0.35) ;
my $lx  = $cx + 5 ;
my $ly  = $y1 - 4 ;

my $path  = qq{M$cx,$y1 L$x2,$y1 L$x2,$y2 L$cx,$y2} ;
my $apts  = qq{$cx,$y2 } . ($cx + $AH) . ',' . ($y2 - int($AH/2)) . ' ' . ($cx + $AH) . ',' . ($y2 + int($AH/2)) ;
my $lesc  = $self->esc($label) ;

push @{$layers->{fg}},
	qq{  <path d="$path" fill="none" stroke="$color" stroke-width="1.5"/>},
	qq{  <polygon points="$apts" fill="$color"/>},
	qq{  <text x="$lx" y="$ly" font-family="$FONT" font-size="$FONT_SZ" fill="$G->{label}">$lesc</text>} ;
}

# ------------------------------------------------------------------------------

sub svg_destroy
{
my ($self, $col, $row, $color) = @_ ;

my $G  = $self->geometry() ;
my $CW = $G->{col_width} ;
my $RH = $G->{row_height} ;

$color //= $G->{destroy} ;

my $r  = int($RH * 0.4) ;
my $px = $col * $CW ;
my $py = $row * $RH + $RH / 2 ;

return
	(
	qq{  <line x1="} . ($px-$r) . qq{" y1="} . ($py-$r) . qq{" x2="} . ($px+$r) . qq{" y2="} . ($py+$r) . qq{" stroke="$color" stroke-width="2"/>},
	qq{  <line x1="} . ($px+$r) . qq{" y1="} . ($py-$r) . qq{" x2="} . ($px-$r) . qq{" y2="} . ($py+$r) . qq{" stroke="$color" stroke-width="2"/>},
	) ;
}

# ------------------------------------------------------------------------------

sub svg_block_rect
{
my ($self, $start_y, $end_y, $operator, $label, $total_width) = @_ ;

my $G      = $self->geometry() ;
my $CW     = $G->{col_width} ;
my $RH     = $G->{row_height} ;
my $FONT   = $G->{font_family} ;
my $SML_SZ = $G->{small_size} ;

my $by     = $start_y * $RH ;
my $bh     = ($end_y - $start_y) * $RH ;
my $bw     = $total_width * $CW - 4 ;
my $fill   = $G->{block_fill} ;
my $stroke = $self->css_block_color($operator) // $G->{block_stroke} ;
my $tcolor = $self->css_block_color($operator) // $G->{block_label} ;
my $op_esc = $self->esc(uc($operator)) ;
my $ty     = $by + $SML_SZ + 3 ;
my $lbl    = defined $label ? ' ' . $self->esc($label) : '' ;

return
	(
	qq{  <rect x="2" y="$by" width="$bw" height="$bh" rx="2" ry="2" fill="$fill" stroke="$stroke" stroke-width="1" opacity="0.35"/>},
	qq{  <text x="6" y="$ty" font-family="$FONT" font-size="$SML_SZ" font-weight="bold" fill="$tcolor">[$op_esc$lbl]</text>},
	) ;
}

# ------------------------------------------------------------------------------

sub render
{
my ($self) = @_ ;

my $G      = $self->geometry() ;
my $CW     = $G->{col_width} ;
my $RH     = $G->{row_height} ;
my $ACT_W  = $G->{act_bar_width} ;
my $lifeline_color_default = $G->{lifeline_color} ;
my $lifeline_width         = $G->{lifeline_width} ;
my $lifeline_dash          = $G->{lifeline_dash} ;

$self->collect_participants($self->{ast}{statements}) ;
$self->compute_layout() ;

my @order = @{$self->{order}} ;

my $content_rows = $self->count_rows($self->{ast}{statements}) ;
my $total_height = $FIRST_Y + $content_rows + $FOOTER_GAP ;

my $last_p    = $self->{participants}{$order[-1]} ;
my $min_width = $last_p->{x} + $last_p->{box_half} + $MARGIN ;
my $width     = $self->compute_max_text_width($self->{ast}{statements}, $min_width) ;

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

my $W = ($width + 4) * $CW ;
my $H = ($total_height + 1) * $RH ;

# Three drawing layers — blocks, then structural elements, then content
my %layers =
	(
	bg  => [],   # block rectangles
	mid => [],   # lifelines, activation bars, participant boxes
	fg  => [],   # arrows, labels, annotations, destroy markers
	) ;

# lifelines
for my $name (@order)
	{
	my $p       = $self->{participants}{$name} ;
	my $cx      = $p->{x} * $CW ;
	my $start_y = ($state{create_y}{$name}
		? $state{create_y}{$name} + 3
		: $LIFELINE_START) * $RH ;
	my $end_y   = ($state{destroy_y}{$name} // $total_height) * $RH ;
	my $color   = $self->css_color($name, 'lifeline') // $lifeline_color_default ;

	push @{$layers{mid}}, qq{  <line x1="$cx" y1="$start_y" x2="$cx" y2="$end_y" stroke="$color" stroke-width="$lifeline_width" stroke-dasharray="$lifeline_dash"/>}
		if $end_y > $start_y ;
	}

# activation bars
for my $span (@{$state{act_spans}})
	{
	my $cx     = $self->participant_x($span->{name}) * $CW ;
	my $bx     = $cx - $ACT_W / 2 ;
	my $by     = $span->{start_y} * $RH ;
	my $bh     = ($span->{end_y} - $span->{start_y}) * $RH ;
	my $fill   = $self->css_color($span->{name}, 'activebar') // $G->{activebar_fill} ;
	my $stroke = $G->{activebar_stroke} ;

	push @{$layers{mid}}, qq{  <rect x="$bx" y="$by" width="$ACT_W" height="$bh" fill="$fill" stroke="$stroke" stroke-width="1"/>}
		if $bh > 0 ;
	}

# participant header boxes
for my $name (@order)
	{
	next if $state{create_y}{$name} ;
	next if $self->{participants}{$name}{deferred} ;
	push @{$layers{mid}}, $self->svg_participant_box($name, 0) ;
	}

# content
my $current_y = $FIRST_Y ;
$self->svg_process_statements($self->{ast}{statements}, \%layers, \$current_y, \%state, $width) ;

my @out ;
push @out, qq{<?xml version="1.0" encoding="UTF-8"?>} ;
push @out, qq{<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">} ;
push @out, $self->svg_defs() ;
push @out, qq{  <rect width="$W" height="$H" fill="white"/>} ;
push @out, @{$layers{bg}} ;
push @out, @{$layers{mid}} ;
push @out, @{$layers{fg}} ;
push @out, '</svg>' ;

return join("\n", @out) . "\n" ;
}

# ------------------------------------------------------------------------------

sub svg_process_statements
{
my ($self, $statements, $layers, $y_ref, $state, $total_width) = @_ ;

my $G       = $self->geometry() ;
my $CW      = $G->{col_width} ;
my $RH      = $G->{row_height} ;
my $FONT    = $G->{font_family} ;
my $FONT_SZ = $G->{font_size} ;
my $MONO    = $G->{mono_family} ;
my $SML_SZ  = $G->{small_size} ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;
	my $y    = $$y_ref ;

	if ($type eq 'Interaction')
		{
		my $src_x = $self->participant_x($node->{source}) * $CW ;
		my $tgt_x = $self->participant_x($node->{target}) * $CW ;
		my $label = $node->{label} // '' ;
		my $style = $ARROW_STYLE{$node->{arrow}} // 'solid' ;
		my $color = $self->css_color($node->{source}, 'arrow') // $G->{arrow} ;
		my $ay    = $y * $RH + int($RH * 0.65) ;
		my $ly    = $y * $RH + int($RH * 0.3) ;

		if ($src_x == $tgt_x)
			{
			$self->svg_self_arrow($src_x, $ay, $label, $color, $layers) ;
			}
		else
			{
			my $direction = $src_x < $tgt_x ? 'right' : 'left' ;
			my $lx        = ($src_x + $tgt_x) / 2 ;
			my $lesc      = $self->esc($label) ;
			push @{$layers->{fg}},
				qq{  <text x="$lx" y="$ly" text-anchor="middle" font-family="$FONT" font-size="$FONT_SZ" fill="$G->{label}">$lesc</text>},
				$self->svg_arrow_line($src_x, $ay, $tgt_x, $direction, $style, $color) ;
			}

		$$y_ref += 2 ;
		}
	elsif ($type eq 'Create')
		{
		$self->register($node->{name}, $node->{alias}) ;
		push @{$layers->{mid}}, $self->svg_participant_box($node->{name}, $y) ;

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
			my $ax1   = $best_x * $CW ;
			my $ax2   = ($tgt_x - $tgt_half) * $CW ;
			my $ay    = ($y + 2) * $RH + int($RH * 0.65) ;
			my $ly    = ($y + 2) * $RH + int($RH * 0.3) ;
			my $lx    = ($ax1 + $ax2) / 2 ;
			my $color = $self->css_color($node->{name}, 'arrow') // $G->{arrow} ;
			push @{$layers->{fg}},
				qq{  <text x="$lx" y="$ly" text-anchor="middle" font-family="$FONT" font-size="$FONT_SZ" fill="$G->{label}">create</text>},
				$self->svg_arrow_line($ax1, $ay, $ax2, 'right', 'dashed', $color) ;
			}

		$$y_ref += 4 ;
		}
	elsif ($type eq 'Destroy')
		{
		my $color = $self->css_color($node->{name}, 'destroy') // $G->{destroy} ;
		push @{$layers->{fg}}, $self->svg_destroy($self->participant_x($node->{name}), $y, $color) ;
		$$y_ref += 2 ;
		}
	elsif ($type eq 'Activate' || $type eq 'Deactivate')
		{
		# drawn in measure pass
		}
	elsif ($type eq 'State')
		{
		my $p     = $node->{participants}[0] ;
		my $cx    = $self->participant_x($p) * $CW ;
		my $ty    = $y * $RH + int($RH * 0.65) ;
		my $color = $self->css_color($p, 'annotations') // $G->{annotation} ;
		my $lesc  = $self->esc('{' . $node->{label} . '}') ;
		push @{$layers->{fg}}, qq{  <text x="$cx" y="$ty" text-anchor="middle" font-family="$MONO" font-size="$SML_SZ" fill="$color">$lesc</text>} ;
		$$y_ref += 2 ;
		}
	elsif ($type eq 'Note')
		{
		my $p     = $node->{participants}[0] ;
		my $cx    = $self->participant_x($p) * $CW ;
		my $ty    = $y * $RH + int($RH * 0.65) ;
		my $color = $self->css_color($p, 'annotations') // $G->{annotation} ;
		my $lesc  = $self->esc($node->{label}) ;
		push @{$layers->{fg}}, qq{  <text x="$cx" y="$ty" text-anchor="middle" font-family="$FONT" font-size="$SML_SZ" font-style="italic" fill="$color">&#x2605; $lesc</text>} ;
		$$y_ref += 2 ;
		}
	elsif ($type eq 'Reference')
		{
		my $p     = $node->{participants}[0] ;
		my $cx    = $self->participant_x($p) * $CW ;
		my $ty    = $y * $RH + int($RH * 0.65) ;
		my $color = $self->css_color($p, 'annotations') // $G->{annotation} ;
		my $lesc  = $self->esc($node->{label}) ;
		push @{$layers->{fg}}, qq{  <text x="$cx" y="$ty" text-anchor="middle" font-family="$FONT" font-size="$SML_SZ" fill="$color">ref: $lesc</text>} ;
		$$y_ref += 2 ;
		}
	elsif ($type eq 'Block')
		{
		my $start_y = $$y_ref ;
		$$y_ref += 2 ;
		$self->svg_process_statements($node->{body}, $layers, $y_ref, $state, $total_width) ;
		push @{$layers->{bg}}, $self->svg_block_rect($start_y, $$y_ref, lc($node->{operator}), $node->{label}, $total_width) ;
		}
	elsif ($type eq 'AltBlock')
		{
		for my $branch (@{$node->{branches}})
			{
			my $start_y = $$y_ref ;
			$$y_ref += 2 ;
			$self->svg_process_statements($branch->{body}, $layers, $y_ref, $state, $total_width) ;
			my $lbl = defined $branch->{label} ? $branch->{label} : '(else)' ;
			push @{$layers->{bg}}, $self->svg_block_rect($start_y, $$y_ref, 'alt', $lbl, $total_width) ;
			}
		}
	}
}

1 ;
