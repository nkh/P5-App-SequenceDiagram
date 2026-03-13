package SequenceDiagram::Canvas ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

use open qw(:std :utf8) ;

use Array::Iterator::Circular ;

# ------------------------------------------------------------------------------

sub new
{
my ($class, $debug, $width, $height) = @_ ;

return bless
	{
	grid   => [map { [(' ') x $width] } 1 .. $height],
	colors => [map { [(undef)  x $width] } 1 .. $height],
	width  => $width,
	height => $height,
	debug  => $debug,
	}, $class ;
}

# ------------------------------------------------------------------------------

sub dbg
{
my ($self, $method, @args) = @_ ;

return unless $self->{debug} ;

printf "canvas  %-22s  %s\n", $method, join('  ', @args) ;
}

# ------------------------------------------------------------------------------

sub draw_vertical_line
{
my ($self, $x, $y, $length, $char, $color) = @_ ;

$char //= '|' ;

$self->dbg('draw_vertical_line', $x, $y, "length=$length char=$char") ;

for (my $i = 0; $i < $length; $i++)
	{
	if ($y + $i < $self->{height})
		{
		$self->{grid}  [$y + $i][$x] = $char ;
		$self->{colors}[$y + $i][$x] = $color if defined $color ;
		}
	}
}

# ------------------------------------------------------------------------------

sub draw_horizontal_line
{
my ($self, $x, $y, $length, $char, $color) = @_ ;

$char //= '-' ;

my $is_iter = ref($char) ;

$self->dbg('draw_horizontal_line', $x, $y, "length=$length") ;

for (my $i = 0; $i < $length; $i++)
	{
	if ($x + $i < $self->{width})
		{
		my $c = $is_iter ? $char->next() : $char ;
		$self->{grid}  [$y][$x + $i] = $c ;
		$self->{colors}[$y][$x + $i] = $color if defined $color ;
		}
	}
}

# ------------------------------------------------------------------------------

sub write_text
{
my ($self, $x, $y, $text, $color) = @_ ;

$self->dbg('write_text', $x, $y, "text=$text") ;

my @chars = split //, $text ;

for (my $i = 0; $i < @chars; $i++)
	{
	if ($x + $i < $self->{width})
		{
		$self->{grid}  [$y][$x + $i] = $chars[$i] ;
		$self->{colors}[$y][$x + $i] = $color if defined $color ;
		}
	}
}

# ------------------------------------------------------------------------------

sub draw_box
{
my ($self, $x, $y, $label, $chars, $color) = @_ ;

$chars //= {} ;

my $tl = $chars->{participant_tl} // '+' ;
my $tr = $chars->{participant_tr} // '+' ;
my $bl = $chars->{participant_bl} // '+' ;
my $br = $chars->{participant_br} // '+' ;
my $h  = $chars->{participant_h}  // '-' ;
my $v  = $chars->{participant_v}  // '|' ;

my $inner = length($label) + 2 ;

$self->dbg('draw_box', $x, $y, "label=$label") ;

$self->write_text($x, $y,     $tl . ($h x $inner) . $tr, $color) ;
$self->write_text($x, $y + 1, $v  . ' ' . $label . ' ' . $v, $color) ;
$self->write_text($x, $y + 2, $bl . ($h x $inner) . $br, $color) ;
}

# ------------------------------------------------------------------------------

sub draw_actor_box
{
my ($self, $x, $y, $label, $chars, $color) = @_ ;

$chars //= {} ;

my $tl = $chars->{actor_tl} // '.' ;
my $tr = $chars->{actor_tr} // '.' ;
my $bl = $chars->{actor_bl} // "'" ;
my $br = $chars->{actor_br} // "'" ;
my $h  = $chars->{actor_h}  // '-' ;
my $v  = $chars->{actor_v}  // '|' ;

my $inner = length($label) + 2 ;

$self->dbg('draw_actor_box', $x, $y, "label=$label") ;

$self->write_text($x, $y,     $tl . ($h x $inner) . $tr, $color) ;
$self->write_text($x, $y + 1, $v  . ' ' . $label . ' ' . $v, $color) ;
$self->write_text($x, $y + 2, $bl . ($h x $inner) . $br, $color) ;
}

# ------------------------------------------------------------------------------

sub draw_horizontal_arrow
{
my ($self, $x, $y, $length, $direction, $style, $chars, $color) = @_ ;

$direction //= 'right' ;
$style     //= 'solid' ;
$chars     //= {} ;

my $h       = $chars->{arrow_h}      // '-' ;
my $dashed  = $chars->{arrow_dashed} // ' ' ;
my $right   = $chars->{arrow_right}  // '>' ;
my $left    = $chars->{arrow_left}   // '<' ;

$self->dbg('draw_horizontal_arrow', $x, $y, "length=$length dir=$direction style=$style") ;

my $line_char = $style eq 'dashed'
	? Array::Iterator::Circular->new($h, $dashed)
	: Array::Iterator::Circular->new($h, $h) ;

if ($direction eq 'right')
	{
	$self->draw_horizontal_line($x,           $y, $length, $line_char, $color) ;
	$self->write_text          ($x + $length, $y, $right, $color) ;
	}
else
	{
	$self->draw_horizontal_line($x + 1,       $y, $length, $line_char, $color) ;
	$self->write_text          ($x,           $y, $left, $color) ;
	}
}

# ------------------------------------------------------------------------------

sub render
{
my ($self, $colorize) = @_ ;

my @lines ;

for my $row_i (0 .. $self->{height} - 1)
	{
	my $row       = $self->{grid}[$row_i] ;
	my $color_row = $self->{colors}[$row_i] ;
	my $line      = '' ;

	if ($colorize)
		{
		require Term::ANSIColor ;

		my $cur_color = undef ;
		my $buf       = '' ;

		for my $col_i (0 .. $self->{width} - 1)
			{
			my $ch  = $row->[$col_i] ;
			my $col = $color_row->[$col_i] ;

			if (($col // '') ne ($cur_color // ''))
				{
				$line .= $cur_color
					? Term::ANSIColor::colored($buf, $cur_color)
					: $buf ;
				$buf       = '' ;
				$cur_color = $col ;
				}

			$buf .= $ch ;
			}

		$line .= $cur_color
			? Term::ANSIColor::colored($buf, $cur_color)
			: $buf ;
		}
	else
		{
		$line = join '', @$row ;
		}

	$line =~ s/ +$// ;
	push @lines, $line ;
	}

while (@lines && $lines[-1] eq '') { pop @lines }

return join "\n", @lines ;
}

1 ;
