use strict ;
use warnings ;

use Test::More tests => 9 ;

use_ok 'SequenceDiagram::AST' ;
use_ok 'SequenceDiagram::Canvas' ;
use_ok 'SequenceDiagram::Lexer' ;
use_ok 'SequenceDiagram::Parser' ;
use_ok 'SequenceDiagram::Linter' ;
use_ok 'SequenceDiagram::Renderer' ;
use_ok 'SequenceDiagram::SVGRenderer' ;
use_ok 'SequenceDiagram::Config::Defaults' ;
use_ok 'SequenceDiagram::Config::Parser' ;
