package SequenceDiagram::Config::Defaults ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

# Default color cycle — 8 slots, cycling by participant declaration order
my @COLORS =
	(
	{
	color       => 'bright_blue',
	lifeline    => 'blue',
	activebar   => 'bright_cyan',
	annotations => 'blue',
	arrow       => 'bright_blue',
	destroy     => 'bright_red',
	},
	{
	color       => 'bright_green',
	lifeline    => 'green',
	activebar   => 'bright_green',
	annotations => 'green',
	arrow       => 'bright_green',
	destroy     => 'bright_red',
	},
	{
	color       => 'bright_yellow',
	lifeline    => 'yellow',
	activebar   => 'bright_yellow',
	annotations => 'yellow',
	arrow       => 'bright_yellow',
	destroy     => 'bright_red',
	},
	{
	color       => 'bright_magenta',
	lifeline    => 'magenta',
	activebar   => 'bright_magenta',
	annotations => 'magenta',
	arrow       => 'bright_magenta',
	destroy     => 'bright_red',
	},
	{
	color       => 'bright_cyan',
	lifeline    => 'cyan',
	activebar   => 'bright_cyan',
	annotations => 'cyan',
	arrow       => 'bright_cyan',
	destroy     => 'bright_red',
	},
	{
	color       => 'bright_red',
	lifeline    => 'red',
	activebar   => 'bright_red',
	annotations => 'red',
	arrow       => 'bright_red',
	destroy     => 'bright_red',
	},
	{
	color       => 'white',
	lifeline    => 'white',
	activebar   => 'bright_white',
	annotations => 'white',
	arrow       => 'white',
	destroy     => 'bright_red',
	},
	{
	color       => 'bright_white',
	lifeline    => 'white',
	activebar   => 'bright_white',
	annotations => 'white',
	arrow       => 'bright_white',
	destroy     => 'bright_red',
	},
	) ;

# Default block colors — one per operator, plus a fallback
my %BLOCKS =
	(
	loop     => 'cyan',
	alt      => 'magenta',
	critical => 'bright_red',
	opt      => 'yellow',
	break    => 'red',
	par      => 'green',
	assert   => 'bright_white',
	neg      => 'red',
	seq      => 'white',
	strict   => 'white',
	default  => 'white',
	) ;

# ASCII character set — no Unicode characters
my %ASCII =
	(
	participant_tl => '.',
	participant_tr => '.',
	participant_bl => "'",
	participant_br => "'",
	participant_h  => '-',
	participant_v  => '|',

	actor_tl => '.',
	actor_tr => '.',
	actor_bl => "'",
	actor_br => "'",
	actor_h  => '-',
	actor_v  => '|',

	lifeline   => '|',
	activation => '#',

	arrow_h      => '-',
	arrow_dashed => ' ',
	arrow_right  => '>',
	arrow_left   => '<',

	destroy_tl => '\\',
	destroy_tc => 'X',
	destroy_tr => '/',
	destroy_bl => '/',
	destroy_bc => 'X',
	destroy_br => '\\',
	) ;

# Unicode character set
my %UNICODE =
	(
	participant_tl => "\x{256D}",
	participant_tr => "\x{256E}",
	participant_bl => "\x{2570}",
	participant_br => "\x{256F}",
	participant_h  => "\x{2500}",
	participant_v  => "\x{2502}",

	actor_tl => "\x{256D}",
	actor_tr => "\x{256E}",
	actor_bl => "\x{2570}",
	actor_br => "\x{256F}",
	actor_h  => "\x{2500}",
	actor_v  => "\x{2502}",

	lifeline   => "\x{2502}",
	activation => "\x{2590}",

	arrow_h      => "\x{2500}",
	arrow_dashed => "\x{254C}",
	arrow_right  => "\x{2B9E}",
	arrow_left   => "\x{2B9C}",

	destroy_tl => '\\',
	destroy_tc => 'X',
	destroy_tr => '/',
	destroy_bl => '/',
	destroy_bc => 'X',
	destroy_br => '\\',
	) ;

# Linter severity table
my %SEVERITY =
	(
	duplicate_participant           => 'error',
	alias_shadows_participant       => 'error',
	create_duplicate                => 'error',
	destroy_undeclared              => 'error',
	destroy_duplicate               => 'warning',
	destroy_implicit                => 'warning',
	activate_destroyed              => 'error',
	double_activate                 => 'warning',
	deactivate_inactive             => 'warning',
	deactivate_no_activate          => 'warning',
	still_active                    => 'warning',
	self_interaction                => 'warning',
	post_destroy_interaction        => 'error',
	conditional_destroy_interaction => 'warning',
	implicit_participant            => 'warning',
	unused_participant              => 'warning',
	undeclared_participant          => 'warning',
	alt_single_branch               => 'warning',
	empty_block                     => 'warning',
	block_no_label                  => 'warning',
	nested_critical                 => 'error',
	break_outside_loop              => 'error',
	filter_unknown_message          => 'warning',
	ignore_and_consider             => 'error',
	) ;

# ------------------------------------------------------------------------------

# SVG geometry and typography defaults
my %SVG =
	(
	# Geometry
	font_family      => 'Arial, Helvetica, sans-serif',
	font_size        => 30,
	mono_family      => q{'Courier New', Courier, monospace},
	small_size       => 27,
	col_width        => 18,
	row_height       => 56,
	box_radius       => 7,
	act_bar_width    => 17,
	arrowhead_size   => 16,
	self_arrow_width => 68,

	# Lifeline appearance
	lifeline_color   => '#4a5568',
	lifeline_width   => 2,
	lifeline_dash    => '8,5',

	# SVG colors
	participant_stroke => '#4a5568',
	participant_fill   => '#f7fafc',
	participant_text   => '#1a202c',
	activebar_fill     => '#bee3f8',
	activebar_stroke   => '#2b6cb0',
	arrow              => '#2d3748',
	label              => '#1a202c',
	destroy            => '#c53030',
	block_stroke       => '#718096',
	block_fill         => '#edf2f7',
	block_label        => '#4a5568',
	annotation         => '#4a5568',
	) ;

my %THEMES =
	(
	light =>
		{
		participant_stroke => '#4a5568',
		participant_fill   => '#f7fafc',
		participant_text   => '#1a202c',
		lifeline_color     => '#4a5568',
		activebar_fill     => '#bee3f8',
		activebar_stroke   => '#2b6cb0',
		arrow              => '#2d3748',
		label              => '#1a202c',
		destroy            => '#c53030',
		block_stroke       => '#718096',
		block_fill         => '#edf2f7',
		block_label        => '#4a5568',
		annotation         => '#4a5568',
		},
	dark =>
		{
		participant_stroke => '#90cdf4',
		participant_fill   => '#1a202c',
		participant_text   => '#e2e8f0',
		lifeline_color     => '#718096',
		activebar_fill     => '#2c5282',
		activebar_stroke   => '#63b3ed',
		arrow              => '#e2e8f0',
		label              => '#e2e8f0',
		destroy            => '#fc8181',
		block_stroke       => '#4a5568',
		block_fill         => '#2d3748',
		block_label        => '#90cdf4',
		annotation         => '#90cdf4',
		},
	monochrome =>
		{
		participant_stroke => '#000000',
		participant_fill   => '#ffffff',
		participant_text   => '#000000',
		lifeline_color     => '#555555',
		activebar_fill     => '#dddddd',
		activebar_stroke   => '#000000',
		arrow              => '#000000',
		label              => '#000000',
		destroy            => '#000000',
		block_stroke       => '#888888',
		block_fill         => '#f0f0f0',
		block_label        => '#333333',
		annotation         => '#333333',
		},
	solarized =>
		{
		participant_stroke => '#268bd2',
		participant_fill   => '#fdf6e3',
		participant_text   => '#657b83',
		lifeline_color     => '#93a1a1',
		activebar_fill     => '#eee8d5',
		activebar_stroke   => '#268bd2',
		arrow              => '#586e75',
		label              => '#586e75',
		destroy            => '#dc322f',
		block_stroke       => '#93a1a1',
		block_fill         => '#eee8d5',
		block_label        => '#2aa198',
		annotation         => '#2aa198',
		},
	) ;

# ------------------------------------------------------------------------------

sub colors   { return [ map { {%$_} } @COLORS ] }
sub blocks   { return {%BLOCKS} }
sub ascii    { return {%ASCII} }
sub unicode  { return {%UNICODE} }
sub severity { return {%SEVERITY} }
sub svg      { return {%SVG} }
sub themes   { return {%THEMES} }

1 ;
