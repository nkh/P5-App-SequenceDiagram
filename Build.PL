use strict ;
use warnings ;

use Module::Build ;

my $builder = Module::Build->new
	(
	module_name        => 'App::SequenceDiagram',
	license            => 'artistic_2',
	dist_author        => 'Nadim Khemir <nadim.khemir@gmail.com>',
	dist_version_from  => 'lib/SequenceDiagram/Renderer.pm',
	dist_abstract      => 'sequence diagram parser with ASCII, Unicode, and SVG renderers',

	requires =>
		{
		'perl'                      => '5.010',
		'Data::TreeDumper'          => '0',
		'Getopt::Long'              => '0',
		'List::Util'                => '0',
		'Array::Iterator::Circular' => '0',
		'Term::ANSIColor'           => '0',
		},

	build_requires =>
		{
		'Test::More'       => '0',
		'Test::Exception'  => '0',
		},

	configure_requires => { 'Module::Build' => 0.42 },

	script_files => ['script/rsd'],

	share_files =>
		{
		'ecsds.md'          => 'ecsds.md',
		'ecsds.ebnf'        => 'ecsds.ebnf',
		'ecsds_tests.ecsds' => 'ecsds_tests.ecsds',
		'rsd.rc'            => 'rsd.rc',
		},

	meta_merge =>
		{
		resources =>
			{
			repository => 'https://github.com/nkh/P5-App-SequenceDiagram',
			},
		},
	) ;

$builder->create_build_script() ;
