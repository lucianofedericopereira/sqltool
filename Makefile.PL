use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'App::sqltool',
    VERSION_FROM     => 'sqltool',
    ABSTRACT         => 'Local MySQL/MariaDB instance manager for development',
    AUTHOR           => 'Luciano Federico Pereira <lucianopereira@posteo.es>',
    LICENSE          => 'lgpl_2_1',
    MIN_PERL_VERSION => '5.010',

    EXE_FILES        => ['sqltool'],

    PREREQ_PM        => {
        # Core modules only - no external dependencies
    },

    META_MERGE       => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/lucianofedericopereira/sqltool.git',
                web  => 'https://github.com/lucianofedericopereira/sqltool',
            },
            bugtracker => {
                web => 'https://github.com/lucianofedericopereira/sqltool/issues',
            },
            homepage => 'https://github.com/lucianofedericopereira/sqltool',
        },
        keywords => [
            'mysql',
            'mariadb',
            'database',
            'development',
            'local',
            'instance',
            'manager',
        ],
        no_index => {
            directory => ['assets'],
        },
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES => 'App-sqltool-*' },
);
