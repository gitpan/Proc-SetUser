use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Proc::SetUser',
    license             => 'restrictive',
    dist_author         => 'Dylan Martin <dmartin@sccd.ctc.edu>',
    dist_version_from   => 'lib/Proc/SetUser.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'Proc-SetUser-*' ],
	create_makefile_pl	=> 'traditional',
	create_readme		=> 1,
);

$builder->create_build_script();
