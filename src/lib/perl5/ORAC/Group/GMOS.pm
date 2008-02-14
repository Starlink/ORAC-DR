package ORAC::Group::GMOS;

=head1 NAME

ORAC::Group::GMOS - class for dealing with GMOS observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::GMOS;

  $Grp = new ORAC::Group::GMOS("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to GMOS. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::GMOS> objects.

=cut

# A package to describe a UKIRT group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;
use vars qw/$VERSION/;
use ORAC::Group::UKIRT;

# Set inheritance
use base qw/ ORAC::Group::UKIRT /;

 '$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for GMOS should go here
my %hdr = (
            EXPOSURE_TIME        => "EXP_TIME",
            DEC_SCALE            => "CDELT2",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            GAIN                 => "GAIN",
            RA_SCALE             => "CDELT1",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
            UTDATE               => "DATE",
            UTEND                => "UTEND",
            UTSTART              => "UTSTART"
	  );

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.
ORAC::Group::GMOS->_generate_orac_lookup_methods( \%hdr );

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::GMOS> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::GMOS;
   $Grp = new ORAC::Group::GMOS("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'g'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('gf');
  $group->filesuffix('.sdf');

  # return the new object
  return $group;
}

=back

=head2 General Methods

=over 4

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
