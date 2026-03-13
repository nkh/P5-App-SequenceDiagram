use strict ;
use warnings ;

use Test::More ;

use SequenceDiagram::Lexer ;
use SequenceDiagram::Parser ;

sub parse
{
my ($text) = @_ ;

my $tokens = SequenceDiagram::Lexer->new($text, 0)->tokenize() ;
my $parser = SequenceDiagram::Parser->new($tokens, $text, {}) ;

return $parser->parse_diagram() ;
}

sub first { parse($_[0])->{statements}[0] }

# empty diagram
{
my $ast = parse('') ;
is $ast->{type}, 'Diagram', 'empty diagram type' ;
is scalar @{$ast->{statements}}, 0, 'empty diagram has no statements' ;
}

# participant declaration
{
my $n = first('participant Client') ;
is $n->{type},    'Participant', 'participant type' ;
is $n->{keyword}, 'participant', 'participant keyword' ;
is $n->{name},    'Client',      'participant name' ;
ok !exists $n->{alias},  'no alias when absent' ;
ok !exists $n->{active}, 'no active when absent' ;
ok !exists $n->{data},   'no data when absent' ;
}

# actor
{
my $n = first('actor User') ;
is $n->{keyword}, 'actor', 'actor keyword' ;
}

# participant with alias
{
my $n = first('participant "Large Unit" as LU') ;
is $n->{name},  'Large Unit', 'quoted participant name' ;
is $n->{alias}, 'LU',         'participant alias' ;
}

# participant with active
{
my $n = first('participant Server active') ;
ok $n->{active}, 'participant active flag set' ;
}

# participant options in any order
{
my $n = first('participant Server active as S') ;
ok $n->{active},      'active before as' ;
is $n->{alias}, 'S',  'alias after active' ;
}

# participant with data
{
my $n = first('participant DB data { type: postgres }') ;
like $n->{data}, qr/type: postgres/, 'participant data captured' ;
}

# create
{
my $n = first('create Session : DBSession') ;
is $n->{type},      'Create',    'create type' ;
is $n->{name},      'Session',   'create name' ;
is $n->{type_name}, 'DBSession', 'create type_name' ;
}

# create without type
{
my $n = first('create Session') ;
is $n->{type}, 'Create',  'create without type_name' ;
ok !exists $n->{type_name}, 'no type_name when absent' ;
}

# destroy
{
my $n = first('participant X') ;
my $ast = parse("participant X\ndestroy X") ;
my $d   = $ast->{statements}[1] ;
is $d->{type}, 'Destroy', 'destroy type' ;
is $d->{name}, 'X',       'destroy name' ;
}

# activate / deactivate
{
my $ast = parse("participant S\nactivate S\ndeactivate S") ;
is $ast->{statements}[1]{type}, 'Activate',   'activate type' ;
is $ast->{statements}[2]{type}, 'Deactivate', 'deactivate type' ;
is $ast->{statements}[1]{name}, 'S',          'activate name' ;
}

# interaction
{
my $n = first('A -> B : hello') ;
is $n->{type},   'Interaction', 'interaction type' ;
is $n->{source}, 'A',           'interaction source' ;
is $n->{arrow},  '->',          'interaction arrow' ;
is $n->{target}, 'B',           'interaction target' ;
is $n->{label},  'hello',       'interaction label' ;
}

# interaction with dashed arrow
{
my $n = first('A --> B : reply') ;
is $n->{arrow}, '-->', 'dashed arrow' ;
}

# interaction with async arrow
{
my $n = first('A ->> B : event') ;
is $n->{arrow}, '->>', 'async arrow' ;
}

# self-interaction
{
my $n = first('A -> A : self') ;
is $n->{source}, 'A', 'self-interaction source' ;
is $n->{target}, 'A', 'self-interaction target' ;
}

# state
{
my $n = first('state A : connected') ;
is $n->{type},  'State', 'state type' ;
is $n->{label}, 'connected', 'state label' ;
is_deeply $n->{participants}, ['A'], 'state single participant' ;
}

# state with multiple participants
{
my $n = first('state A B C : synced') ;
is_deeply $n->{participants}, ['A', 'B', 'C'], 'state three participants' ;
}

# state with comma-separated participants
{
my $n = first('state A, B : synced') ;
is_deeply $n->{participants}, ['A', 'B'], 'state comma-separated participants' ;
}

# note
{
my $n = first('note A B : "important"') ;
is $n->{type},  'Note',      'note type' ;
is $n->{label}, 'important', 'note label' ;
is_deeply $n->{participants}, ['A', 'B'], 'note participants' ;
}

# ref
{
my $n = first('ref A B : "auth flow"') ;
is $n->{type},  'Reference', 'reference type' ;
is $n->{label}, 'auth flow', 'reference label' ;
is_deeply $n->{participants}, ['A', 'B'], 'reference participants' ;
}

# ignore with braces
{
my $n = first('ignore { login logout }') ;
is $n->{type}, 'Ignore', 'ignore type' ;
is_deeply $n->{messages}, ['login', 'logout'], 'ignore messages (braces)' ;
}

# ignore with colon
{
my $n = first('ignore : login, logout') ;
is $n->{type}, 'Ignore', 'ignore colon syntax' ;
is_deeply $n->{messages}, ['login', 'logout'], 'ignore messages (colon)' ;
}

# consider
{
my $n = first('consider { query }') ;
is $n->{type}, 'Consider', 'consider type' ;
is_deeply $n->{messages}, ['query'], 'consider messages' ;
}

# simple block
{
my $n = first("loop \"3 times\"\n\t{\n\tA -> B : ping\n\t}") ;
is $n->{type},     'Block', 'loop block type' ;
is $n->{operator}, 'LOOP',  'loop operator upcased' ;
is $n->{label},    '3 times', 'loop label' ;
is scalar @{$n->{body}}, 1, 'loop body has one statement' ;
is $n->{body}[0]{type}, 'Interaction', 'loop body contains interaction' ;
}

# block without label
{
my $n = first("par\n\t{\n\tA -> B : x\n\t}") ;
is $n->{type},     'Block', 'par block type' ;
ok !exists $n->{label}, 'no label when absent' ;
}

# all simple block operators parse
for my $op (qw(opt loop par critical break assert neg seq strict))
	{
	my $n = first("$op \"label\"\n\t{\n\tA -> B : x\n\t}") ;
	is $n->{type},     'Block',    "$op block type" ;
	is $n->{operator}, uc($op),    "$op operator" ;
	}

# alt block
{
my $n = first("alt \"valid\"\n\t{\n\tA -> B : ok\n\t}\nelse \"invalid\"\n\t{\n\tA -> B : fail\n\t}") ;
is $n->{type},             'AltBlock', 'alt type' ;
is scalar @{$n->{branches}}, 2,        'alt has two branches' ;
is $n->{branches}[0]{label}, 'valid',   'alt first branch label' ;
is $n->{branches}[1]{label}, 'invalid', 'alt second branch label' ;
is $n->{branches}[0]{body}[0]{type}, 'Interaction', 'alt branch body' ;
}

# alt with labelless else
{
my $n = first("alt \"cond\"\n\t{\n\tA -> B : x\n\t}\nelse\n\t{\n\tA -> B : y\n\t}") ;
is scalar @{$n->{branches}}, 2, 'alt with bare else has two branches' ;
ok !exists $n->{branches}[1]{label}, 'bare else has no label' ;
}

# nested blocks
{
my $n = first("loop \"outer\"\n\t{\n\topt \"inner\"\n\t\t{\n\t\tA -> B : x\n\t\t}\n\t}") ;
is $n->{body}[0]{type},     'Block', 'nested block type' ;
is $n->{body}[0]{operator}, 'OPT',   'nested block operator' ;
}

# comment is ignored by parser
{
my $ast = parse("# comment\nA -> B : hello") ;
is scalar @{$ast->{statements}}, 1, 'comment does not produce a statement' ;
}

# multiple statements
{
my $ast = parse("participant A\nparticipant B\nA -> B : hello\nB --> A : world") ;
is scalar @{$ast->{statements}}, 4, 'four statements parsed' ;
}

# parse error — missing arrow
{
do { eval { parse('A B : hello') } ; ok $@, 'missing arrow causes die' } ;
}

# parse error — missing colon in interaction
{
do { eval { parse('A -> B hello') } ; ok $@, 'missing colon in interaction causes die' } ;
}

# parse error — missing block body
{
do { eval { parse('loop "x"') } ; ok $@, 'missing block body causes die' } ;
}

# error message contains source line
{
my $err = '' ;
eval { parse("participant Client\nA B : hello") } ;
$err = $@ ;
like $err, qr/A B : hello/, 'error message contains source line' ;
like $err, qr/\^/,          'error message contains caret' ;
}

done_testing ;
