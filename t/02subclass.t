use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;
use Test::Fatal;
use Test::Warnings;

{
    package A;
    use Moose;
    with qw(MooseX::ConfigFromFile);

    sub get_config_from_file { }
}

{
    package B;
    use Moose;
    extends qw(A);
}

ok(B->does('MooseX::ConfigFromFile'), 'B does ConfigFromFile');
is(exception { B->new_with_config() }, undef, 'B->new_with_config lives');

