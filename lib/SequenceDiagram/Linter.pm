package SequenceDiagram::Linter ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

use SequenceDiagram::Config::Defaults ;

# ------------------------------------------------------------------------------

sub new
{
my ($class, $severity) = @_ ;

$severity //= SequenceDiagram::Config::Defaults::severity() ;

return bless
	{
	severity       => $severity,
	messages       => [],
	declared       => {},
	active         => {},
	used           => {},
	destroyed      => {},
	cond_destroyed => {},
	ref_labels     => [],
	all_activates  => {},
	all_messages   => {},
	has_ignore     => 0,
	has_consider   => 0,
	}, $class ;
}

# ------------------------------------------------------------------------------

sub emit
{
my ($self, $check, $msg, $loc) = @_ ;

my $sev  = $self->{severity}{$check} // 'warning' ;
my $pos  = $loc ? "line $loc->{line} col $loc->{col}" : '' ;
my $text = "[$sev] $msg" . ($pos ? " at $pos" : '') ;

push @{$self->{messages}}, $text ;
}

# ------------------------------------------------------------------------------

sub check
{
my ($self, $ast) = @_ ;

$self->pre_scan($ast->{statements}) ;
$self->scan($ast->{statements}, { depth => 0, block_stack => [], critical_depth => 0 }) ;
$self->check_end_state() ;

return @{$self->{messages}} ;
}

# ------------------------------------------------------------------------------

sub pre_scan
{
my ($self, $statements) = @_ ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;

	if    ($type eq 'Activate')   { $self->{all_activates}{$node->{name}} = 1 }
	elsif ($type eq 'Interaction') { $self->{all_messages}{$node->{label}} = 1 }
	elsif ($type eq 'Ignore')     { $self->{has_ignore}   = 1 }
	elsif ($type eq 'Consider')   { $self->{has_consider} = 1 }
	elsif ($type eq 'Block')      { $self->pre_scan($node->{body}) }
	elsif ($type eq 'AltBlock')   { $self->pre_scan($_->{body}) for @{$node->{branches}} }
	}
}

# ------------------------------------------------------------------------------

sub declare
{
my ($self, $name, $alias, $loc, $explicit) = @_ ;

$self->{declared}{$name} = { loc => $loc, explicit => $explicit }
	unless exists $self->{declared}{$name} ;

$self->emit('alias_shadows_participant', "Alias '$alias' shadows existing participant '$alias'", $loc)
	if defined $alias && exists $self->{declared}{$alias} ;
}

# ------------------------------------------------------------------------------

sub scan
{
my ($self, $statements, $ctx) = @_ ;

for my $node (@$statements)
	{
	my $type = $node->{type} ;
	my $loc  = $node->{loc} ;

	if ($type eq 'Participant')
		{
		my $name = $node->{name} ;
		if (exists $self->{declared}{$name})
			{
			$self->emit('duplicate_participant', "Participant '$name' already declared", $loc) ;
			}
		else
			{
			$self->declare($name, $node->{alias}, $loc, 1) ;
			$self->{active}{$name} = 1 if $node->{active} ;
			}
		}
	elsif ($type eq 'Create')
		{
		my $name = $node->{name} ;
		if (exists $self->{declared}{$name})
			{
			$self->emit('create_duplicate', "Participant '$name' already declared; cannot create", $loc) ;
			}
		else
			{
			$self->declare($name, $node->{alias}, $loc, 1) ;
			$self->{active}{$name} = 1 if $node->{active} ;
			}
		}
	elsif ($type eq 'Destroy')
		{
		my $name = $node->{name} ;
		if (!exists $self->{declared}{$name})
			{
			$self->emit('destroy_undeclared', "Destroying undeclared participant '$name'", $loc) ;
			}
		elsif ($self->{destroyed}{$name} || $self->{cond_destroyed}{$name})
			{
			$self->emit('destroy_duplicate', "Participant '$name' already destroyed", $loc) ;
			}
		else
			{
			$self->emit('destroy_implicit', "Destroying implicitly declared participant '$name'", $loc)
				unless $self->{declared}{$name}{explicit} ;
			if ($ctx->{depth} == 0)
				{
				$self->{destroyed}{$name} = $loc ;
				}
			else
				{
				$self->{cond_destroyed}{$name} = $loc ;
				}
			delete $self->{active}{$name} ;
			}
		}
	elsif ($type eq 'Activate')
		{
		my $name = $node->{name} ;
		$self->declare($name, undef, $loc, 0) unless exists $self->{declared}{$name} ;
		if ($self->{destroyed}{$name})
			{
			$self->emit('activate_destroyed', "Activating destroyed participant '$name'", $loc) ;
			}
		else
			{
			my $current = $self->{active}{$name} // 0 ;
			$self->emit('double_activate', "Participant '$name' activated while already active", $loc)
				if $current > 0 ;
			$self->{active}{$name} = $current + 1 ;
			}
		}
	elsif ($type eq 'Deactivate')
		{
		my $name = $node->{name} ;
		$self->declare($name, undef, $loc, 0) unless exists $self->{declared}{$name} ;
		if (!$self->{all_activates}{$name})
			{
			$self->emit('deactivate_no_activate', "Participant '$name' deactivated but never activated anywhere in diagram", $loc) ;
			}
		elsif (($self->{active}{$name} // 0) <= 0)
			{
			$self->emit('deactivate_inactive', "Deactivating inactive participant '$name'", $loc) ;
			}
		else
			{
			$self->{active}{$name}-- ;
			}
		}
	elsif ($type eq 'Interaction')
		{
		for my $p ($node->{source}, $node->{target})
			{
			unless (exists $self->{declared}{$p})
				{
				$self->declare($p, undef, $loc, 0) ;
				$self->emit('implicit_participant', "Participant '$p' is implicitly declared", $loc) ;
				}
			$self->emit('post_destroy_interaction', "Participant '$p' is destroyed but used in interaction", $loc)
				if $self->{destroyed}{$p} ;
			$self->emit('conditional_destroy_interaction', "Participant '$p' was conditionally destroyed but used in interaction", $loc)
				if $self->{cond_destroyed}{$p} ;
			$self->{used}{$p} = 1 ;
			}
		$self->emit('self_interaction', "Participant '$node->{source}' sends message to itself", $loc)
			if $node->{source} eq $node->{target} ;
		}
	elsif ($type eq 'State' || $type eq 'Note' || $type eq 'Reference')
		{
		for my $p (@{$node->{participants}})
			{
			$self->declare($p, undef, $loc, 0) unless exists $self->{declared}{$p} ;
			}
		push @{$self->{ref_labels}}, $node->{label} if $type eq 'Reference' ;
		}
	elsif ($type eq 'Block')
		{
		my $op = $node->{operator} ;

		$self->emit('block_no_label', "Block '$op' has no label", $loc)
			if !defined $node->{label} && grep { $_ eq $op } qw(loop critical) ;

		$self->emit('empty_block', "Block '$op' has empty body", $loc)
			unless @{$node->{body}} ;

		$self->emit('nested_critical', "Nested 'critical' block is not allowed", $loc)
			if $op eq 'critical' && $ctx->{critical_depth} > 0 ;

		$self->emit('break_outside_loop', "'break' used outside a 'loop' block", $loc)
			if $op eq 'break' && !grep { $_ eq 'loop' } @{$ctx->{block_stack}} ;

		my $inner =
			{
			depth          => $ctx->{depth} + 1,
			block_stack    => [@{$ctx->{block_stack}}, $op],
			critical_depth => $ctx->{critical_depth} + ($op eq 'critical' ? 1 : 0),
			} ;

		$self->scan($node->{body}, $inner) ;
		}
	elsif ($type eq 'AltBlock')
		{
		my @branches = @{$node->{branches}} ;

		$self->emit('alt_single_branch', "'alt' with a single branch should be 'opt'", $loc)
			if @branches == 1 ;

		my $inner =
			{
			depth          => $ctx->{depth} + 1,
			block_stack    => [@{$ctx->{block_stack}}, 'alt'],
			critical_depth => $ctx->{critical_depth},
			} ;

		for my $i (0 .. $#branches)
			{
			my $branch  = $branches[$i] ;
			my $is_last = ($i == $#branches) ;

			$self->emit('block_no_label', 'alt branch has no label', $branch->{loc})
				if !defined $branch->{label} && !$is_last ;

			$self->emit('empty_block', 'alt branch has empty body', $branch->{loc})
				unless @{$branch->{body}} ;

			$self->scan($branch->{body}, $inner) ;
			}
		}
	elsif ($type eq 'Ignore')
		{
		$self->emit('filter_unknown_message', "Ignored message '$_' does not appear in any interaction", $loc)
			for grep { !$self->{all_messages}{$_} } @{$node->{messages}} ;
		}
	elsif ($type eq 'Consider')
		{
		$self->emit('filter_unknown_message', "Considered message '$_' does not appear in any interaction", $loc)
			for grep { !$self->{all_messages}{$_} } @{$node->{messages}} ;
		}
	}
}

# ------------------------------------------------------------------------------

sub check_end_state
{
my ($self) = @_ ;

$self->emit('ignore_and_consider', "'ignore' and 'consider' cannot both appear in the same diagram")
	if $self->{has_ignore} && $self->{has_consider} ;

for my $name (sort keys %{$self->{declared}})
	{
	my $loc = $self->{declared}{$name}{loc} ;

	$self->emit('undeclared_participant', "Participant '$name' was never explicitly declared", $loc)
		unless $self->{declared}{$name}{explicit} ;

	$self->emit('unused_participant', "Participant '$name' is declared but never used in an interaction", $loc)
		unless $self->{used}{$name} || $self->{destroyed}{$name} || $self->{cond_destroyed}{$name} ;

	$self->emit('still_active', "Participant '$name' is still active at end of diagram", $loc)
		if ($self->{active}{$name} // 0) > 0 ;
	}
}

1 ;
