#!perl

# Test ORAC::Frame::NDF [relies on Starlink::HDSPACK]

use strict;
use warnings;
use Test::More tests => 11;
use ORAC::Constants qw/ ORAC__OK ORAC__ERROR/;

# Need create_hdsobj
use Starlink::HDSPACK 1.12;

require_ok("ORAC::Frame::NDF");

# instantiate without a frame
my $frm = new ORAC::Frame::NDF;
isa_ok($frm,"ORAC::Frame");

# Create a temporary file on disk
my $root = "tmp$$";
my $suffix = '.sdf';

# Create a file
Starlink::HDSPACK::create_hdsobj($root, 'NDF');

ok(-e $root.$suffix, "Check that NDF exists");


$frm->file( $root );

# erase it
is( $frm->erase, ORAC__OK, "Erase file");

# Check
ok( ! -e $root.$suffix, "Make sure it has gone");

# Now with a HDS container
Starlink::HDSPACK::create_hdsobj($root, 'UKIRTHDS');
ok(-e $root.$suffix, "Check that HDS exists");

Starlink::HDSPACK::create_hdsobj($root.".I1", 'NDF');
Starlink::HDSPACK::create_hdsobj($root.".I2", 'NDF');
Starlink::HDSPACK::create_hdsobj($root.".HEADER", 'NDF');

# Erase each component (but not the .HEADER)
$frm->file($root .".I1");
is( $frm->erase, ORAC__OK, "Erase I1");
ok( -e $root.$suffix, "File should still be there");

$frm->file($root .".I2");
is( $frm->erase, ORAC__OK, "Erase I2");
ok( !-e $root.$suffix, "File should be gone");

# Cause an error
$frm->file($root .".I3");
is( $frm->erase, ORAC__ERROR, "Erase something that is not there");
