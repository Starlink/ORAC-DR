package ORAC::Inst::SCUBA;

=head1 NAME

ORAC::Inst::SCUBA - ORAC description of SCUBA

=head1 SYNOPSIS

  use ORAC::Inst::SCUBA;

  $inst = new ORAC::Inst::SCUBA;

  @messys = $inst->start_msg_sys;
  %Mon = $inst->start_algorithm_engines;
  $status = $inst->wait_for_algorithm_engines;

=head1 DESCRIPTION

This module configures the system for the instrument. This primarily
involves configuring the messaging and algorithm engine environment
and is independent of the C<ORAC::Frame> definition.

Algorithm engine definitions can be found in C<ORAC::Inst::Defn>.

=cut

use Carp;
use strict;
use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

use base qw/ ORAC::Inst::ADAM /;

# Status handling
use ORAC::Constants qw/:status/;
use ORAC::Inst::Defn qw/ orac_determine_initial_algorithm_engines /;

=head1 METHODS

=over 4

=item B<start_algorithm_engines>

Starts the algorithm engines and returns a hash containing
the objects associated with each monolith.
The routine returns when all the last monolith can be contacted
(so requires that messaging has been initialised before this
routine is called).

SCUBA uses SURF (surf_mon)
and  KAPPA (kapview_mon, kappa_mon, ndfpack_mon)

As well as some less frequently used monoliths from
CCDPACK (ccdpack_ref), POLPACK (polpack_mon), CURSA (catselect)
[for polarimetry] and CONERT (ndf2fits) for FITS conversion.

=cut

sub start_algorithm_engines {
  my $self = shift;

  # Retrieve algorithm requirements
  my @engines = orac_determine_initial_algorithm_engines( 'SCUBA' );

  # Now launch them
  return $self->_launch_algorithm_engines( @engines );

}

=back

=head1 SEE ALSO

L<ORAC::Inst::IRCAM>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

