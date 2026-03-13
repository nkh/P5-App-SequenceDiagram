use strict ;
use warnings ;

use Test::More ;

use SequenceDiagram::Lexer ;

sub tokenize { SequenceDiagram::Lexer->new($_[0], 0)->tokenize() }

sub types  { [map { $_->[0] } @{tokenize($_[0])}] }
sub token_values { [map { $_->[1] } @{tokenize($_[0])}] }

# reserved keywords
is_deeply types('participant actor'), ['RESERVED', 'RESERVED'],
	'participant and actor are reserved' ;

is_deeply types('activate deactivate'), ['RESERVED', 'RESERVED'],
	'activate and deactivate are reserved' ;

is_deeply types('alt else'), ['RESERVED', 'RESERVED'],
	'alt and else are reserved' ;

is_deeply
	types('opt loop par critical break assert neg seq strict'),
	[('RESERVED') x 9],
	'all block operators are reserved' ;

is_deeply types('ignore consider'), ['RESERVED', 'RESERVED'],
	'ignore and consider are reserved' ;

is_deeply types('create destroy'), ['RESERVED', 'RESERVED'],
	'create and destroy are reserved' ;

is_deeply types('state note ref'), ['RESERVED', 'RESERVED', 'RESERVED'],
	'state note ref are reserved' ;

is_deeply types('as active data'), ['RESERVED', 'RESERVED', 'RESERVED'],
	'as active data are reserved' ;

# quoted reserved word is a QUOTED not RESERVED
is_deeply types('"participant"'), ['QUOTED'],
	'quoted reserved word is QUOTED' ;

is_deeply token_values('"participant"'), ['participant'],
	'quoted value excludes quotes' ;

# plain name
is_deeply types('Client'), ['NAME'],
	'unquoted non-reserved is NAME' ;

# quoted string
is_deeply types('"hello world"'), ['QUOTED'],
	'quoted string is QUOTED' ;

is_deeply token_values('"hello world"'), ['hello world'],
	'quoted string value excludes quotes' ;

# arrows
is_deeply types('->'),  ['ARROW'], '-> is ARROW' ;
is_deeply types('-->'), ['ARROW'], '--> is ARROW' ;
is_deeply types('->>'), ['ARROW'], '->> is ARROW' ;

is_deeply token_values('->'),  ['->'],  '-> value correct' ;
is_deeply token_values('-->'), ['-->'], '--> value correct' ;
is_deeply token_values('->>'), ['->>', ], '->> value correct' ;

# punctuation
is_deeply types(':'), ['COLON'], 'colon is COLON' ;
is_deeply types(','), ['COMMA'], 'comma is COMMA' ;
is_deeply types('{'), ['BRACE'], 'open brace is BRACE' ;
is_deeply types('}'), ['BRACE'], 'close brace is BRACE' ;

# comment is ignored
is_deeply types("# this is a comment\nClient"), ['NAME'],
	'comment is ignored' ;

# blank lines ignored
is_deeply types("Client\n\nServer"), ['NAME', 'NAME'],
	'blank lines ignored' ;

# data block
my $tokens = tokenize("data { some content here }") ;
is $tokens->[0][0], 'RESERVED', 'data keyword is RESERVED' ;
is $tokens->[1][0], 'DATA',     'data block content is DATA' ;
like $tokens->[1][1], qr/some content here/, 'data block captures content' ;

# source position
my $tok = tokenize("Client")->[0] ;
is $tok->[2]{line}, 1, 'token line is 1' ;
is $tok->[2]{col},  1, 'token col is 1' ;

my $tok2 = tokenize("  Server")->[0] ;
is $tok2->[2]{col}, 3, 'token col accounts for leading spaces' ;

# unknown token produces a CHAR token, not a die
do { my $t = tokenize('@broken') ; is $t->[0][0], 'CHAR', 'unknown token produces CHAR token' } ;

# unterminated data block
do { eval { tokenize('data { unclosed') } ; ok $@, 'unterminated data block causes die' } ;

done_testing ;
