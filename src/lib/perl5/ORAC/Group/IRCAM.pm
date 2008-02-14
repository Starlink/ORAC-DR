package ORAC::Group::IRCAM;

=head1 NAME

ORAC::Group::IRCAM - IRCAM class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::IRCAM("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to IRCAM. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::IRCAM> objects. 

=cut

# A package to describe a IRCAM group object for the
# ORAC pipeline

use 5.006;
use Carp;

# standard error module and turn on strict
use warnings;
use strict;

use ORAC::Group::UKIRT;

# Set inheritance
use base qw/ ORAC::Group::UKIRT /;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for IRCAM should. go here.
my %hdr = (
            DEC_SCALE            => "CDELT1",
            DEC_TELESCOPE_OFFSET => "DECOFF",
            DETECTOR_BIAS        => "DET_BIAS",
            EXPOSURE_TIME        => "DEXPTIME",
            GAIN                 => "DEPERDN",
            RA_SCALE             => "CDELT2",
            RA_TELESCOPE_OFFSET  => "RAOFF",
            UTDATE               => "IDATE",
            UTEND                => "RUTEND",
            UTSTART              => "RUTSTART"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::IRCAM->_generate_orac_lookup_methods( \%hdr );

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::IRCAM> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::IRCAM;
   $Grp = new ORAC::Group::IRCAM("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'gi'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('gi');
  $group->filesuffix('.sdf');

  # return the new object
  return $group;
}

=back

=head2 General Methods

=over 4

=back

=head1 SEE ALSO

L<ORAC::Group::UKIRT>, L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
