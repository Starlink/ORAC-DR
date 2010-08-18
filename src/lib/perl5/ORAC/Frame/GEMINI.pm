package ORAC::Frame::GEMINI;

=head1 NAME

ORAC::Frame::GEMINI - class for dealing with GEMINI observation files in ORAC-DR

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to GEMINI. It provides a class derived from B<ORAC::Frame::UKIRT>.

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

Paul Hirst <p.hirst@jach.hawaii.edu>
Malcolm J. Currie <mjc@star.rl.ac.uk>

=cut


1;
