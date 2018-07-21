package ORAC::Inst::LCOFLOYDS;

=head1 NAME

ORAC::Inst::LCOFLOYDS - ORAC description of LCOFLOYDS

=head1 SYNOPSIS

  use ORAC::Inst::LCOFLOYDS;

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
$VERSION = '1.00';

use base qw/ ORAC::Inst /;

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

LCOFLOYDS uses KAPPA (kappa_mon), FIGARO and CCDPACK.

=cut


sub start_algorithm_engines {

  my $self = shift;

  # Retrieve algorithm requirements
  my @engines = orac_determine_initial_algorithm_engines( 'LCOFLOYDS' );

  # Now launch them
  return $self->_launch_algorithm_engines( @engines );

}

=item B<return_possible_calibrations>

Returns an array containing a list of the possible calibrations
for this instrument.

=cut

sub return_possible_calibrations {
  my $self = shift;
  return ( "bias", "dark", "flat", "lambert" );

}

=item B<sort_my_groups>

Sorts Groups into order so calibrations come first

=cut

sub sort_my_groups {
  my $self = shift;
  my ($SortGroups) = shift;

  sub by_grouptype {
    my %sorthash = (
                    BIAS => 0,
                    DARK => 1,
                    FLAT => 2,
                    SKYFLAT => 2,
                    ARC => 2,
                    OBJECT => 3,
                    EXPOSE => 3,
                  );
    if ($sorthash{$a->members->[0]->uhdr( "ORAC_OBSERVATION_TYPE")} < $sorthash{$b->members->[0]->uhdr( "ORAC_OBSERVATION_TYPE")}) {
      return -1;
    } elsif ($sorthash{$a->members->[0]->uhdr( "ORAC_OBSERVATION_TYPE")} == $sorthash{$b->members->[0]->uhdr( "ORAC_OBSERVATION_TYPE")}) {
      return 0;
    } elsif ($sorthash{$a->members->[0]->uhdr( "ORAC_OBSERVATION_TYPE")} > $sorthash{$b->members->[0]->uhdr( "ORAC_OBSERVATION_TYPE")}) {
      return 1;
    }
  }
  print "Sorted groups\n";
  my @NewGroups = sort by_grouptype @$SortGroups;
  return (\@NewGroups);
}

=back

=head1 SEE ALSO

L<ORAC::Inst::LCOSPECTRAL>,  L<ORAC::Inst::IRCAM>

=head1 AUTHORS

Tim Lister E<lt>tlister@lcogt.netE<gt>,
Paul Hirst E<lt>p.hirst@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>.

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;

