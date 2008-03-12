package ORAC::Group::SCUBA2;

=head1 NAME

ORAC::Group::SCUBA2 - SCUBA2 class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::SCUBA2("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to SCUBA2. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::SCUBA2> objects.

=cut

# A package to describe a SCUBA2 group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;
use Carp;
our $VERSION;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

use ORAC::Group::NDF;

use base qw/ ORAC::Group::NDF /;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of an B<ORAC::Group::SCUBA2> object. This method
takes an optional argument containing the name of the new group.
The object identifier is returned.

  $Grp = new ORAC::Group::SCUBA2;
  $Grp = new ORAC::Group::SCUBA2("group_name");

This method calls the base class constructor but initialises the group
with a file suffix if ".sdf" and a fixed part of "ga".

=cut

sub new {
  my $proto = shift;
  my $class = ref( $proto ) || $proto;

# Do not pass objects if the constructor required
# knowledge of fixedpart() and filesuffix().
  my $group = $class->SUPER::new(@_);

# Configure it.
  $group->fixedpart('gs');
  $group->filesuffix('.sdf');

# And return the new object.
  return $group;
}

=item B<file_from_bits>

Method to return the group filename derived from a fixed variable part
(eg UT), a group designator (usually obs number) and the observing
wavelength. The full filename is returned (including suffix).

  $file = $Grp->file_from_bits("UT","num","wavelen");

For SCUBA-2 the return string is of the format

  fixedpart . prefix . '_' . number . '_' . wavelen . suffix

where the number is a 5-digit zero-padded integer and the wavelen is
either 850 or 450.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $num = shift;
  my $wavelen = shift;

  if ( defined($prefix) && defined($num) && defined($wavelen) ) {
    # Zero-pad the obsnum
    $num = sprintf "%05d", $num;

    # Return name
    return $self->fixedpart . $prefix . '_' . $num . '_'.$wavelen . $self->filesuffix;
  } else {
    croak "Group file_from_bits method requires three arguments\n";
  }
}

=back

=head2 General Methods

=over 4

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;
