package ORAC::Group::IRIS2;

=head1 NAME

ORAC::Group::IRIS2 - IRIS2 class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::IRIS2("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to IRIS2. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::IRIS2> objects.

=cut

# A package to describe a IRIS2 group object for the
# ORAC pipeline

use 5.006;
use Carp;

# standard error module and turn on strict
use warnings;
use strict;

use ORAC::Group::UKIRT;

# Set inheritance
use base qw/ ORAC::Group::NDF /;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::IRIS2> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::IRIS2;
   $Grp = new ORAC::Group::IRIS2("group_name");

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

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames. For IRIS2 this
number is decimal UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set. Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME - same format as SCUBA uses

  # First get the time of day
  my $time = $self->hdr('UTSTART');
  if (defined $time) {
    # Need to split on :
    my ($h,$m,$s) = split(/:/,$time);
    $time = $h + $m/60 + $s/3600;
  } else {
    $time = 0;
  }

  # Now get the UT date
  my $date = $self->hdr('UTDATE');
  if (defined $date) {
    my ($y,$m,$d) = split(/:/, $date);
    $date = $y . '0'x (2-length($m)) . $m . '0'x (2-length($d)) . $d;
  } else {
    $date = 0;
  }

  my $ut = $date + ( $time / 24.0 );

  # Update the header
  $self->hdr('ORACTIME', $ut);
  $self->hdr('ORACUT',   $date);

  $new{'ORACTIME'} = $ut;
  $new{ORACUT} = $date;

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
