package ORAC::Group::SPEX;

=head1 NAME

ORAC::Group::SPEX - SPEX class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::SPEX("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that are
specific to SPEX.  It provides a class derived from
B<ORAC::Group::UKIRT>. All the methods available to B<ORAC::Group>
objects are available to B<ORAC::Group::SPEX> objects.

=cut

# A package to describe a SPEX group object for the
# ORAC-DR pipeline.

use 5.006;
use Carp;

# standard error module and turn on strict
use warnings;
use strict;

use ORAC::Group::UKIRT;
use ORAC::Constants;
use ORAC::General;

# Set inheritance
use base qw/ ORAC::Group::UKIRT /;

use vars qw/$VERSION/;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::SPEX> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::SPEX;
   $Grp = new ORAC::Group::SPEX("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'gcc'.

=cut

sub new {
   my $proto = shift;
   my $class = ref( $proto ) || $proto;

# Do not pass objects if the constructor required knowledge of
# fixedpart() and filesuffix().
   my $group = $class->SUPER::new(@_);

# Configure it.
   $group->fixedpart( 'gspex' );
   $group->filesuffix( '.sdf' );

# Return the new object.
   return $group;
}

=back

=head2 General Methods

=over 4

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
