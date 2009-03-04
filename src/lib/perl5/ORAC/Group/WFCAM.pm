package ORAC::Group::WFCAM;

=head1 NAME

ORAC::Group::WFCAM - class for dealing with WFCAM observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::WFCAM;

  $Grp = new ORAC::Group::WFCAM("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to WFCAM. It provides a class derived from B<ORAC::Group::UFTI>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::WFCAM> objects.

=cut

# A package to describe a WFCAM group object for the
# ORAC pipeline.

use 5.006;
use strict;
use warnings;
use vars qw/$VERSION/;
use ORAC::Group::UFTI;
use ORAC::General;

# Set inheritance.
use base qw/ ORAC::Group::UFTI /;

$VERSION = '1.0';

# Set the group fixed parts for the four chips.
my %groupfixedpart = ( '1' => 'gw',
                       '2' => 'gx',
                       '3' => 'gy',
                       '4' => 'gz',
                       '5' => 'gv',
                     );

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::WFCAM> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::WFCAM;
   $Grp = new ORAC::Group::WFCAM("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'g'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

# Do not pass objects if the constructor required knowledge
# of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

# Which WFCAM chip is this? We need to know so we know what
# to call the group file.
  my $fixedpart;
  if( $ENV{'ORAC_INSTRUMENT'} =~ /^WFCAM([1-5])$/ ) {
    $fixedpart = $groupfixedpart{$1};
  } else {
    $fixedpart = $groupfixedpart{'1'};
  }

# Configure the object.
  $group->fixedpart($fixedpart);
  $group->filesuffix('.sdf');

# And return the new object.
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

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Science and Technology Facilities Council.
Copyright (C) 2004-2007 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
