package SequenceDiagram::AST ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

# Each constructor returns a hashref representing one AST node.
# Only fields explicitly passed are set — no undef placeholders.

# ------------------------------------------------------------------------------

sub diagram
{
my ($class, %a) = @_ ;

return
	{
	type       => 'Diagram',
	statements => $a{statements},
	} ;
}

# ------------------------------------------------------------------------------

sub participant
{
my ($class, %a) = @_ ;

my $node =
	{
	type    => 'Participant',
	keyword => $a{keyword},
	name    => $a{name},
	loc     => $a{loc},
	} ;

$node->{alias}  = $a{alias}  if defined $a{alias} ;
$node->{active} = 1          if $a{active} ;
$node->{data}   = $a{data}   if defined $a{data} ;

return $node ;
}

# ------------------------------------------------------------------------------

sub create
{
my ($class, %a) = @_ ;

my $node =
	{
	type => 'Create',
	name => $a{name},
	loc  => $a{loc},
	} ;

$node->{type_name} = $a{type_name} if defined $a{type_name} ;
$node->{alias}     = $a{alias}     if defined $a{alias} ;
$node->{active}    = 1             if $a{active} ;
$node->{data}      = $a{data}      if defined $a{data} ;

return $node ;
}

# ------------------------------------------------------------------------------

sub destroy
{
my ($class, %a) = @_ ;

return
	{
	type => 'Destroy',
	name => $a{name},
	loc  => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub activate
{
my ($class, %a) = @_ ;

return
	{
	type => 'Activate',
	name => $a{name},
	loc  => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub deactivate
{
my ($class, %a) = @_ ;

return
	{
	type => 'Deactivate',
	name => $a{name},
	loc  => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub interaction
{
my ($class, %a) = @_ ;

return
	{
	type   => 'Interaction',
	source => $a{source},
	arrow  => $a{arrow},
	target => $a{target},
	label  => $a{label},
	loc    => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub state
{
my ($class, %a) = @_ ;

return
	{
	type         => 'State',
	participants => $a{participants},
	label        => $a{label},
	loc          => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub note
{
my ($class, %a) = @_ ;

return
	{
	type         => 'Note',
	participants => $a{participants},
	label        => $a{label},
	loc          => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub reference
{
my ($class, %a) = @_ ;

return
	{
	type         => 'Reference',
	participants => $a{participants},
	label        => $a{label},
	loc          => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub ignore
{
my ($class, %a) = @_ ;

return
	{
	type     => 'Ignore',
	messages => $a{messages},
	loc      => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub consider
{
my ($class, %a) = @_ ;

return
	{
	type     => 'Consider',
	messages => $a{messages},
	loc      => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub block
{
my ($class, %a) = @_ ;

my $node =
	{
	type     => 'Block',
	operator => $a{operator},
	body     => $a{body},
	loc      => $a{loc},
	} ;

$node->{label} = $a{label} if defined $a{label} ;

return $node ;
}

# ------------------------------------------------------------------------------

sub alt_block
{
my ($class, %a) = @_ ;

return
	{
	type     => 'AltBlock',
	branches => $a{branches},
	loc      => $a{loc},
	} ;
}

# ------------------------------------------------------------------------------

sub alt_branch
{
my ($class, %a) = @_ ;

my $node =
	{
	body => $a{body},
	loc  => $a{loc},
	} ;

$node->{label} = $a{label} if defined $a{label} ;

return $node ;
}

1 ;
