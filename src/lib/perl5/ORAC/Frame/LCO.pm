package ORAC::Frame::LCO;

=head1 NAME

ORAC::Frame::LCO - class for dealing with LCO observation files in ORAC-DR

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to LCO. It provides a class derived from B<ORAC::Frame::UKIRT>.

=cut

use 5.006;
use strict;
use warnings;

use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame::UKIRT;
use base qw/ORAC::Frame::UKIRT/;

# standard error module and turn on strict
use Carp;

=head1 AUTHORS

Tim Lister (tlister@lcogt.net)

=cut


1;
