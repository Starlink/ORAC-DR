#!perl

use strict;

use Test::More tests => (1 + 5 + 5 + 3 + 3);

use DateTime::Format::ISO8601;
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
    'REDUCE_TEST#FILTER=450' => {
        PARAM_D => 100,
    },
    'REDUCE_TEST:CCC_1#FILTER=450' => {
        PARAM_C => 200,
        PARAM_D => 200,
    },
    'REDUCE_TEST:CCC_1#FILTER=450#SOMETHING=SOMEVALUE' => {
        PARAM_D => 300,
    },
    REDUCE_OTHER => {
        PARAM_A => 4,
    },
    'REDUCE_DATE#DATE=2025-01-01T00:00:00' => {
        PARAM_A => 1,
    },
    'REDUCE_DATE#DATE!=2025-01-01T00:00:00' => {
        PARAM_B => 1,
    },
    'REDUCE_DATE#DATE<=2025-01-01T00:00:00' => {
        PARAM_C => 1,
    },
    'REDUCE_DATE#DATE<2025-01-01T00:00:00' => {
        PARAM_D => 1,
    },
    'REDUCE_DATE#DATE>=2025-01-01T00:00:00' => {
        PARAM_E => 1,
    },
    'REDUCE_DATE#DATE>2025-01-01T00:00:00' => {
        PARAM_F => 1,
    },
    'REDUCE_NUM#VALUE<10' => {
        PARAM_A => 1,
    },
    'REDUCE_NUM#VALUE<=10' => {
        PARAM_B => 1,
    },
    'REDUCE_NUM#VALUE>10' => {
        PARAM_C => 1,
    },
    'REDUCE_NUM#VALUE>=10' => {
        PARAM_D => 1,
    },
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

# Test recipe parameters including filtered matches.
%params = $par->for_recipe('REDUCE_TEST', {ORAC_FILTER => '850'});
is_deeply(\%params, {PARAM_A => 5, PARAM_B => 6});

%params = $par->for_recipe('REDUCE_TEST', {ORAC_FILTER => '450'});
is_deeply(\%params, {PARAM_A => 5, PARAM_B => 6, PARAM_D => 100});

%params = $par->for_recipe('REDUCE_TEST',
    {ORAC_OBJECT => 'AAA_1', ORAC_FILTER => '450'});
is_deeply(\%params,
    {PARAM_A => 5, PARAM_B => 7, PARAM_C => 8, PARAM_D => 100});

%params = $par->for_recipe('REDUCE_TEST',
    {ORAC_OBJECT => 'CCC_1', ORAC_FILTER => '450'});
is_deeply(\%params,
    {PARAM_A => 5, PARAM_B => 6, PARAM_C => 200, PARAM_D => 200});

%params = $par->for_recipe('REDUCE_TEST',
    {ORAC_OBJECT => 'CCC_1', ORAC_FILTER => '450',
     ORAC_SOMETHING => 'SOMEVALUE'});
is_deeply(\%params,
    {PARAM_A => 5, PARAM_B => 6, PARAM_C => 200, PARAM_D => 300});

# Test recipe parameters including date matches.
%params = $par->for_recipe('REDUCE_DATE', {
    ORAC_DATE => DateTime::Format::ISO8601->parse_datetime('2025-01-01')});
is_deeply(\%params, {PARAM_A => 1, PARAM_C => 1, PARAM_E => 1});

%params = $par->for_recipe('REDUCE_DATE', {
    ORAC_DATE => DateTime::Format::ISO8601->parse_datetime('2024-04-01')});
is_deeply(\%params, {PARAM_B => 1, PARAM_C => 1, PARAM_D => 1});

%params = $par->for_recipe('REDUCE_DATE', {
    ORAC_DATE => DateTime::Format::ISO8601->parse_datetime('2025-12-25')});
is_deeply(\%params, {PARAM_B => 1, PARAM_E => 1, PARAM_F => 1});

# Test numeric comparisons
%params = $par->for_recipe('REDUCE_NUM', {ORAC_VALUE => 10});
is_deeply(\%params, {PARAM_B => 1, PARAM_D => 1});

%params = $par->for_recipe('REDUCE_NUM', {ORAC_VALUE => 9});
is_deeply(\%params, {PARAM_A => 1, PARAM_B => 1});

%params = $par->for_recipe('REDUCE_NUM', {ORAC_VALUE => 11});
is_deeply(\%params, {PARAM_C => 1, PARAM_D => 1});
