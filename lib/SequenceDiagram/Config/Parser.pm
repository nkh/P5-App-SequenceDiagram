package SequenceDiagram::Config::Parser ;

our $VERSION = q{0.01} ;

use strict ;
use warnings ;

use SequenceDiagram::Config::Defaults ;

# ------------------------------------------------------------------------------

sub new
{
my ($class) = @_ ;

return bless
	{
	colors    => SequenceDiagram::Config::Defaults::colors(),
	blocks    => SequenceDiagram::Config::Defaults::blocks(),
	chars     => SequenceDiagram::Config::Defaults::ascii(),
	severity  => SequenceDiagram::Config::Defaults::severity(),
	svg       => SequenceDiagram::Config::Defaults::svg(),
	overrides => {},
	}, $class ;
}

# ------------------------------------------------------------------------------

sub load
{
my ($self, $file) = @_ ;

open my $fh, '<', $file or die "Cannot open config '$file': $!\n" ;

my $section = '' ;
my $name    = '' ;
my @slot_colors ;
my %slot_fields ;

while (my $line = <$fh>)
	{
	chomp $line ;
	$line =~ s/#.*$// ;
	$line =~ s/^\s+|\s+$//g ;
	next unless length $line ;

	if ($line =~ /^\[participant\s+(\S+)\]$/)
		{
		$self->flush_slot(\@slot_colors, \%slot_fields) if $section eq 'participant_default' ;
		$section = 'participant_named' ;
		$name    = $1 ;
		%slot_fields = () ;
		}
	elsif ($line =~ /^\[participant\]$/)
		{
		$self->flush_slot(\@slot_colors, \%slot_fields) if $section eq 'participant_default' ;
		$section     = 'participant_default' ;
		$name        = '' ;
		%slot_fields = () ;
		}
	elsif ($line =~ /^\[blocks\]$/)
		{
		$self->flush_slot(\@slot_colors, \%slot_fields) if $section eq 'participant_default' ;
		$section = 'blocks' ;
		}
	elsif ($line =~ /^\[chars\]$/)
		{
		$self->flush_slot(\@slot_colors, \%slot_fields) if $section eq 'participant_default' ;
		$section = 'chars' ;
		}
	elsif ($line =~ /^\[linter\]$/)
		{
		$self->flush_slot(\@slot_colors, \%slot_fields) if $section eq 'participant_default' ;
		$section = 'linter' ;
		}
	elsif ($line =~ /^\[svg\]$/)
		{
		$self->flush_slot(\@slot_colors, \%slot_fields) if $section eq 'participant_default' ;
		$section = 'svg' ;
		}
	elsif ($line =~ /^(\w+)\s*=\s*(.+)$/)
		{
		my ($key, $val) = ($1, $2) ;
		$val =~ s/\s+$// ;

		if ($section eq 'participant_default')
			{
			my @values = $self->parse_values($val) ;
			$slot_fields{$key} = \@values ;
			}
		elsif ($section eq 'participant_named')
			{
			my @values = $self->parse_values($val) ;
			$self->{overrides}{$name}{$key} = $values[0] ;
			}
		elsif ($section eq 'blocks')
			{
			$self->{blocks}{$key} = $val ;
			}
		elsif ($section eq 'chars')
			{
			$self->{chars}{$key} = $self->unescape($val) ;
			}
		elsif ($section eq 'linter')
			{
			$self->{severity}{$key} = $val ;
			}
		elsif ($section eq 'svg')
			{
			$self->{svg}{$key} = $val ;
			}
		}
	}

$self->flush_slot(\@slot_colors, \%slot_fields) if $section eq 'participant_default' ;

close $fh ;

$self->{colors} = \@slot_colors if @slot_colors ;

return $self ;
}

# ------------------------------------------------------------------------------

sub flush_slot
{
my ($self, $slot_colors, $slot_fields) = @_ ;

return unless %$slot_fields ;

my $n = 0 ;
for my $v (values %$slot_fields) { $n = scalar(@$v) if scalar(@$v) > $n }

for my $i (0 .. $n - 1)
	{
	my %slot ;
	for my $field (keys %$slot_fields)
		{
		my $vals = $slot_fields->{$field} ;
		$slot{$field} = $vals->[$i] // $vals->[-1] ;
		}

	# Fill missing fields from 'color' in same slot
	my $base = $slot{color} // 'white' ;
	for my $field (qw(lifeline activebar annotations arrow destroy))
		{
		$slot{$field} //= $base ;
		}

	push @$slot_colors, \%slot ;
	}

%$slot_fields = () ;
}

# ------------------------------------------------------------------------------

sub parse_values
{
my ($self, $str) = @_ ;

my @vals ;
while ($str =~ /("(?:[^"\\]|\\.)*"|[^,]+)/g)
	{
	my $v = $1 ;
	$v =~ s/^\s+|\s+$//g ;
	$v =~ s/^"|"$//g ;
	push @vals, $v ;
	}

return @vals ;
}

# ------------------------------------------------------------------------------

sub unescape
{
my ($self, $str) = @_ ;

$str =~ s/^"//; $str =~ s/"$// ;
$str =~ s/\\n/\n/g ;
$str =~ s/\\t/\t/g ;

return $str ;
}

# ------------------------------------------------------------------------------

sub color_for
{
my ($self, $name, $index, $field) = @_ ;

$field //= 'color' ;

if (exists $self->{overrides}{$name})
	{
	my $ov = $self->{overrides}{$name} ;
	return $ov->{$field} // $ov->{color} ;
	}

my $slots = $self->{colors} ;
return undef unless @$slots ;

my $slot = $slots->[$index % scalar @$slots] ;
return $slot->{$field} // $slot->{color} ;
}

# ------------------------------------------------------------------------------

sub block_color { return $_[0]->{blocks}{$_[1]} // $_[0]->{blocks}{default} }
sub chars       { return $_[0]->{chars} }
sub severity    { return $_[0]->{severity} }
sub svg         { return $_[0]->{svg} }

1 ;
