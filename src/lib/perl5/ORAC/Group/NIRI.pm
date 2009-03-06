package ORAC::Group::NIRI;

=head1 NAME

ORAC::Group::NIRI - class for dealing with NIRI observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::NIRI;

  $Grp = new ORAC::Group::NIRI("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to NIRI. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::NIRI> objects.

=cut

# A package to describe a UKIRT group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;
use vars qw/$VERSION/;
use ORAC::Group::UKIRT;
use ORAC::General;
use Astro::SLA;

# Set inheritance
use base qw/ ORAC::Group::UKIRT /;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group::UKIRT.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::NIRI> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::NIRI;
   $Grp = new ORAC::Group::NIRI("group_name");

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
  $group->fixedpart('gN');
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
