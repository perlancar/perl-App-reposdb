package App::reposdb;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

our $db_schema_spec = {
    latest_v => 2,
    install_v1 => [
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

my %common_args = (
    reposdb_path => {
        schema => 'str*', # XXX path
        tags => ['common'],
    },
);

my %repo_arg = (
    repo => {
        schema => 'str*',
        pos => 0,
    },
);

sub _set_args_default {
    require Cwd;

    my ($args, $set_repo_default) = @_;

    $args->{reposdb_path} //= "$ENV{HOME}/repos.db";
    if ($set_repo_default) {
        my $repo;
        {
            my $cwd = Cwd::getcwd();
            while (1) {
                if (-d ".git") {
                    ($repo = $cwd) =~ s!.+/!!;
                    last;
                }
                chdir ".." or last;
                $cwd =~ s!(.+)/.+!$1! or last;
            }
        }
        $args->{repo} = $repo;
    }
}

sub _connect_db {
    require DBI;
    require SQL::Schema::Versioned;

    my $args = shift;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$args->{reposdb_path}", "", "",
                           {RaiseError=>1});
    my $res = SQL::Schema::Versioned::create_or_update_db_schema(
        dbh => $dbh, spec => $db_schema_spec);
    die "Cannot create/update database schema: $res->[0] - $res->[1]"
        unless $res->[0] == 200;

    $dbh;
}

$SPEC{list_repos} = {
    v => 1.1,
    summary => 'List repositories registered in repos.db',
    args => {
        %common_args,
        detail => {
            schema => 'bool',
            cmdline_aliases => {l=>{}},
        },
    },
};
sub list_repos {
    my %args = @_;

    _set_args_default(\%args);
    my $dbh = _connect_db(\%args);

    my @res;
    my $sth = $dbh->prepare("SELECT * FROM repos");
    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $row;
    }

    my $resmeta = {};
    if ($args{detail}) {
        $resmeta->{'table.fields'} =
            [qw/name commit_time status_time pull_time/];
    } else {
        @res = map { $_->{name} } @res;
    }

    [200, "OK", \@res, $resmeta];
}

$SPEC{touch_repo} = {
    v => 1.1,
    args => {
        %common_args,
        %repo_arg,
        commit_time => {
            schema => [bool => is=>1],
        },
        status_time => {
            schema => [bool => is=>1],
        },
        pull_time => {
            schema => [bool => is=>1],
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
    my %args = @_;

    _set_args_default(\%args, 1);
    my $dbh = _connect_db(\%args);

    return [400, "Please specify repo name"] unless defined $args{repo};

    $dbh->begin_work;
    $dbh->do("INSERT OR IGNORE INTO repos (name) VALUES (?)", {},
             $args{repo});
    my $now = time();
    if ($args{commit_time}) {
        $dbh->do("UPDATE repos SET commit_time=? WHERE name=?", {},
                 $now, $args{repo});
    }
    if ($args{status_time}) {
        $dbh->do("UPDATE repos SET status_time=? WHERE name=?", {},
                 $now, $args{repo});
    }
    if ($args{pull_time}) {
        $dbh->do("UPDATE repos SET pull_time=? WHERE name=?", {},
                 $now, $args{repo});
    }
    $dbh->commit;
    [200];
}

1;
# ABSTRACT: Utility to manipulate repos.db

=head1 SYNOPSIS

See L<reposdb>.


=head1 DESCRIPTION
