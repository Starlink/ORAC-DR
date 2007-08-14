package ORAC::Frame::NIRI2;

=head1 NAME

ORAC::Frame::NIRI2 - class for dealing with older NIRI observation files in ORAC-DR

This module provides methods for handling Frame objects that are
specific to early NIRI data. It provides a class derived from
B<ORAC::Frame::NIRI>.  The main difference is the name format.
The early data only have a three-digit name after the "S".

=cut

# A package to describe a NIRI frame object for the
# ORAC pipeline

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::NIRI;

# Let the object know that it is derived from ORAC::Frame::NIRI;
use base qw/ORAC::Frame::NIRI/;

# standard error module and turn on strict
use Carp;
use strict;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::NIRI>.

=head2 General Methods

=over 4

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts.  A prefix (usually UT) and observation number should
be supplied.

$fname = $Frm->file_from_bits($prefix, $obsnum);

=cut

sub file_from_bits { 

# Obtain object and arguments.
   my $self = shift;
   my $prefix = shift;
   my $obsnum = shift;

# File numbers are padded to 3 digits.
   $obsnum = sprintf( "%03d", $obsnum );

   return $self->rawfixedpart . $prefix . 'S' . $obsnum . $self->rawsuffix;

}

=item B<template>

Create new file name from template. zero-pads.

=cut

sub template {
   my $self = shift;
   my $template = shift;

# Obtain the observation number.
   my $num = $self->number;

# Pad with leading zeroes to give a 3-digit observation number.
   $num = '0' x ( 3-length( $num ) ) . $num;

# Change the first number.
   $template =~ s/_\d+_/_${num}_/;

# Update the filename using the template.
   $self->file( $template );

}

=back

=head1 SEE ALSO

L<ORAC::Group::NIRI>

=head1 AUTHORS

Malcolm J. Currie <mjc@star.rl.ac.uk>
Paul Hirst <p.hirst@jach.hawaii.edu>
Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
