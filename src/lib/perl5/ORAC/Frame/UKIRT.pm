package ORAC::Frame::UKIRT;

=head1 NAME

ORAC::Frame::UKIRT - UKIRT class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::UKIRT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to UKIRT. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::UKIRT> objects.

=cut

use 5.006;
use strict;
use warnings;

# These are the UKIRT generic lookup tables
my %hdr = (
            AIRMASS_START       => "AMSTART",
            AIRMASS_END         => "AMEND",
            DEC_BASE            => "DECBASE",
            DETECTOR_READ_TYPE  => "MODE",
            EQUINOX             => "EQUINOX",
            FILTER              => "FILTER",
	    INSTRUMENT          => "INSTRUME",
            NUMBER_OF_OFFSETS   => "NOFFSETS",
            NUMBER_OF_EXPOSURES => "NEXP",
            OBJECT              => "OBJECT",
            OBSERVATION_NUMBER  => "OBSNUM",
            OBSERVATION_TYPE    => "OBSTYPE",
            RA_BASE             => "RABASE",
            ROTATION            => "CROTA2",
            SPEED_GAIN          => "SPD_GAIN",
            STANDARD            => "STANDARD",
            WAVEPLATE_ANGLE     => "WPLANGLE",
            X_LOWER_BOUND       => "RDOUT_X1",
            X_UPPER_BOUND       => "RDOUT_X2",
            Y_LOWER_BOUND       => "RDOUT_Y1",
            Y_UPPER_BOUND       => "RDOUT_Y2"
        );

# Take this lookup table and generate methods that can
# be sub-classed by other instruments
ORAC::Frame::UKIRT->_generate_orac_lookup_methods( \%hdr );


# A package to describe a UKIRT group object for the
# ORAC pipeline

use vars qw/$VERSION/;
use ORAC::Frame::NDF;
use ORAC::Constants;

# Let the object know that it is derived from ORAC::Frame::NDF;
use base qw/ORAC::Frame::NDF/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


# standard error module and turn on strict
use Carp;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 General Methods

=over 4

=item B<findgroup>

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

The group name stored in the object is automatically updated using 
this value.

=cut

sub findgroup {

  my $self = shift;

  my $hdrgrp = $self->hdr('GRPNUM');
  my $amiagroup;


  if ($self->hdr('GRPMEM')) {
    $amiagroup = 1;
  } elsif (!defined $self->hdr('GRPMEM')){
    $amiagroup = 1;
  } else {
    $amiagroup = 0;
  }

  # Is this group name set to anything useful
  if (!$hdrgrp || !$amiagroup ) {
    # if the group is invalid there is not a lot we can do about
    # it except for the case of certain calibration objects that
    # we know are the only members of their group (eg DARK)

#    if ($self->hdr('OBJECT') eq 'DARK') {
       $hdrgrp = 0;
#    }

  }

  $self->group($hdrgrp);

  return $hdrgrp;

}

=item B<findrecipe>

Find the recipe name. If no recipe can be found from the
'DRRECIPE' FITS keyword'QUICK_LOOK' is returned by default.

The recipe name stored in the object is automatically updated using 
this value.

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('DRRECIPE');

  # Check to see whether there is something there
  # if not try to make something up
  if (!defined($recipe) or $recipe !~ /./) {
    $recipe = 'QUICK_LOOK';
  }

  # Update
  $self->recipe($recipe);

  return $recipe;
}


=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>, L<ORAC::Frame>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

 
1;
