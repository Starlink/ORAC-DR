# Test ORAC::Frame

use strict;
use warnings;
use Test;

BEGIN { plan tests => 16};

use ORAC::Frame;

my $frm = new ORAC::Frame;

ok(1);

# Not associated with any particular type of frame so we are limited
# in what we can test.

ok(ref($frm->hdr), 'HASH');

# set up a header and retrieve it
$frm->uhdr("TEST_HEADER", 52);

ok($frm->uhdr("TEST_HEADER"), 52);

ok($frm->uhdr("UNDEF"),undef);


# Set up some made up file names
# to test file name handling
my @files = qw/a_10 b_10 c_10 d_10 e_10 f_10 g_10/;
$frm->files(@files);

$frm->tagset('TEST'); # tag the current state for later

ok($frm->nfiles, scalar(@files));

ok($frm->file(1), $files[0]);

$frm->file(2,'bb');
ok($frm->file(2), 'bb');
$frm->file(2,'bb_ext');

# Test intermediates
ok($frm->intermediates->[0], 'bb');

# Number test

$frm->raw('c_10');
ok($frm->number, 10);

# GUI_ID
ok($frm->gui_id(2), "s2ext");
ok($frm->gui_id(), "s1num");

# INOUT

my ($in, $out) = $frm->inout("out",2);
ok($out, 'bb_ext_out');

($in, $out) = $frm->inout("foo",3);
ok($out, 'c_10_foo');


# TEMPLATES

$frm->template('c_20_bar', 3);
ok($frm->file(3), 'c_10_bar' );

# TAGs

$frm->tagretrieve('TEST');

ok($frm->file(2), $files[1]);
ok($frm->file(5), $files[4]);



