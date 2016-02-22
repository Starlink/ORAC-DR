#!perl

use strict;

use Test::More tests => (1 + 5);

use ORAC::Recipe::Parameters;

# Create dummy recipe parameters object and configure it manually to
# contain a few entries.
my $par = new ORAC::Recipe::Parameters();

isa_ok($par, 'ORAC::Recipe::Parameters');

$par->_parameters(
    REDUCE_TEST => {
        PARAM_A => 5,
        PARAM_B => 6,
    },
    'REDUCE_TEST:AAA_1' => {
        PARAM_B => 7,
        PARAM_C => 8,
    },
    'REDUCE_TEST:BBB_.' => {
        PARAM_B => 9,
        PARAM_C => 9,
    },
    REDUCE_OTHER => {
        PARAM_A => 4,
    }
);

# Test reading recipe parameters from the object.
my %params;

%params = $par->for_recipe('REDUCE_OTHER');
is_deeply(\%params, {PARAM_A => 4});

%params = $par->for_recipe('REDUCE_OTHER', {ORAC_OBJECT => 'aaa_1'});
is_deeply(\%params, {PARAM_A => 4});

%params = $par->for_recipe('REDUCE_TEST', {ORAC_OBJECT => 'aaa_2'});
is_deeply(\%params, {PARAM_A => 5, PARAM_B => 6});

%params = $par->for_recipe('REDUCE_TEST', {ORAC_OBJECT => 'aaa_1'});
is_deeply(\%params, {PARAM_A => 5, PARAM_B => 7, PARAM_C => 8});

%params = $par->for_recipe('REDUCE_TEST', {ORAC_OBJECT => 'bbb_2'});
is_deeply(\%params, {PARAM_A => 5, PARAM_B => 9, PARAM_C => 9});
