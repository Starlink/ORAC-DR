package ORAC::Group::UKIRT;

=head1 NAME

ORAC::Group::UKIRT - Base class for dealing with groups from UKIRT instruments

=head1 SYNOPSIS

  use ORAC::Group::UKIRT;

  $Grp = new ORAC::Group::UKIRT;

=head1 DESCRIPTION

This class provides UKIRT specific methods for handling groups.

=cut

use 5.006;
use strict;
use warnings;
our $VERSION;

$VERSION = '1.0';

use ORAC::Group::NDF;

use base qw/ ORAC::Group::NDF /;

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;

