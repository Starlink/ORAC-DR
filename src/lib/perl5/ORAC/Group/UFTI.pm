package ORAC::Group::UFTI;

=head1 NAME

ORAC::Group::UFTI - class for dealing with UFTI observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::UFTI;

  $Grp = new ORAC::Group::UFTI("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to UFTI. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::UFTI> objects.

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

# Translation tables for UFTI should go here
my %hdr = (
            EXP_TIME  => "EXP_TIME",
            DECSCALE  => "CDELT2",
            GAIN      => "GAIN",
            RASCALE   => "CDELT1",
            TDECOFF   => "TDECOFF",
            TRAOFF    => "TRAOFF",
            UTEND     => "UTEND",
            UTSTART   => "UTSTART"
	  );

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.
ORAC::Group::UFTI->_generate_orac_lookup_methods( \%hdr );

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::UFTI> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::UFTI;
   $Grp = new ORAC::Group::UFTI("group_name");

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

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

An example is ORACTIME that should be set to the time of the
observation in hours. Instrument specific frame objects
are responsible for setting this value from their header.

Should be run after a header is set. Currently the hdr()
method calls this whenever it is updated.

Calculates ORACUT and ORACTIME

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME
  # For UFTI the keyword is simply UTSTART
  # Just return it (zero if not available)
  my $time = $self->hdr('UTSTART');
  $time = 0 unless (defined $time);
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # Calc ORACUT:
  my $ut = $self->hdr('DATE');
  $ut = 0 unless defined $ut;
  $ut =~ s/-//g;  #  Remove the intervening minus sign

  $self->hdr('ORACUT', $ut);
  $new{ORACUT} = $ut;

  return %new;
}

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
