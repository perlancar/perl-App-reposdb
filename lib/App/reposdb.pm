package App::reposdb;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

our $db_spec = {
    latest_v => 2,
    v1 => [
        "CREATE TABLE repos (
             name TEXT NOT NULL PRIMARY KEY,
             commit_time INT NOT NULL
         )",
    ],
    upgrade_to_v2 => [
        # we lose data :p but this distro first released at v2 anyway
        "DROP TABLE repos",
        "CREATE TABLE repos (
             name TEXT NOT NULL PRIMARY KEY,
             commit_time INT,
             status_time INT,
             pull_time INT
         )",
    ],
    install => [
        "CREATE TABLE repos (
             name TEXT NOT NULL PRIMARY KEY,
             commit_time INT,
             status_time INT,
             pull_time INT
         )",
    ],
};

$SPEC{list_repos} = {
    v => 1.1,
};
sub list_repos {
}

$SPEC{touch_repo} = {
    v => 1.1,
    args => {
        commit_time => {
            schema => [bool => [is=>1]],
        },
        status_time => {
            schema => [bool => [is=>1]],
        },
        pull_time => {
            schema => [bool => [is=>1]],
        },
        to => {
            schema => 'date*',
        },
    },
    args_rels => {
        req_some => [1, 3, [qw/commit_time status_time pull_time/]],
    },
};
sub touch_repo {
}

1;
# ABSTRACT: Utility to manipulate repos.db

=head1 SYNOPSIS

See L<reposdb>.


=head1 DESCRIPTION
