package ORAC::Frame::PICARD;

=head1 NAME

ORAC::Frame::PICARD - Class for handling individual reduced data files via PICARD

=head1 SYNOPSIS

  use ORAC::Frame::PICARD;

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
derived from standalone data products suitable for processing with
PICARD. Each input file corresponds to a single frame.

=cut

use 5.006;
use warnings;
use vars qw/$VERSION/;

# Let the object know that it is derived from ORAC::Frame::NDF;
use base qw/ORAC::Frame::NDF/;

# standard error module and turn on strict
use Carp;
use strict;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::NDF>.

=head2 Constructor

=over 4

=item B<new>

Simple constructor. 

  $Frm = new ORAC::Frame::PICARD( \@files );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawformat('NDF');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object.
  # Currently the argument will be the array reference to the list
  # of filenames, or if there are two args it's the UT date and
  # observation number.
  $self->configure(@_) if @_;

  return $self;
}


=back

=head2 General Methods

=over 4

=item B<findrecipe>

PICARD frames are all processed using the supplied command-line recipe.

=cut

sub findrecipe {
  return "PICARD_RECIPE";
}

=item B<findgroup>

All PICARD frames are in the same group.

=cut

sub findgroup {
  my $self = shift;
  $self->group("PICARD_GROUP");
  return $self->group;
}

=item B<framegroupkeys>

For PICARD, return an empty list.

=cut

sub framegroupkeys {
  return ();
}

=back

=head1 SEE ALSO

L<ORAC::Group::PICARD>

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

$Id$

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.
All Rights Reserved.

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
