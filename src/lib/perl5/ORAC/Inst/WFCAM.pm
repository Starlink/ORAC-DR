package ORAC::Inst::WFCAM;

=head1 NAME

ORAC::Inst::WFCAM - ORAC description of WFCAM

=head1 SYNOPSIS

  use ORAC::Inst::WFCAM;

  %Mon = $inst->start_algorithm_engines;

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

use base qw/ ORAC::Inst /;

# Status handling
use ORAC::Constants qw/:status/;

use ORAC::Inst::Defn qw/ orac_determine_initial_algorithm_engines /;


=head1 METHODS

=over 4

=item B<start_algorithm_engines>

WFCAM uses only cirdr routines, so no algorithm engines are needed.

=cut

sub start_algorithm_engines {
  my $self = shift;
 
  # Retrieve algorithm requirements.
  my @engines = orac_determine_initial_algorithm_engines("WFCAM");
 
  # And launch them.
  return $self->_launch_algorithm_engines( @engines );
 

}

=item B<return_possible_calibrations>

Returns an array containing a list of the possible calibrations
for this instrument.

=cut

sub return_possible_calibrations {
    my $self = shift;
    return ("dark","flat","sky");

}

=back

=head1 SEE ALSO

=head1 REVISION

$Id$

=head1 AUTHORS

Jim Lewis E<lt>jrl@ast.cam.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 2003-2006 Cambridge Astronomy Survey Unit
All Rights Reserved.


=cut

1;
