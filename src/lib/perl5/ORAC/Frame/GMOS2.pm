package ORAC::Frame::GMOS2;

=head1 NAME

ORAC::Frame::GMOS2 - class for dealing with older GMOS observation files in ORAC-DR

This module provides methods for handling Frame objects that are
specific to early (before 2001 March 1) GMOS data.  It provides a
class derived from B<ORAC::Frame::GMOS>.  The main difference is the
name format. The early data only have a three-digit name after the
"S".

=cut

# A package to describe a GMOS frame object for the
# ORAC pipeline

use 5.006;
use warnings;

# standard error module and turn on strict
use Carp;
use strict;

use vars qw/$VERSION/;
use ORAC::Frame::GMOS2;

# Let the object know that it is derived from ORAC::Frame::GMOS;
use base qw/ORAC::Frame::GMOS/;

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::GMOS>.

=head2 General Methods

=over 4

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts.  A prefix (usually UT) and observation number should
be supplied.

$fname = $Frm->file_from_bits($prefix, $obsnum);

=cut

sub file_from_bits {
  print "Hello GMOS2ers\n";

# Obtain object and arguments.
   my $self = shift;
   my $prefix = shift;
   my $obsnum = shift;

# File numbers are padded to three digits.
   $obsnum = sprintf( "%03d", $obsnum );
   print "Filename: " . $self->rawfixedpart . $prefix . 'S' . $obsnum . $self->rawsuffix . "\n";

   return $self->rawfixedpart . $prefix . 'S' . $obsnum . $self->rawsuffix;

}

=item B<template>

Create new file name from template with zero-padding.

=cut

sub template {
   my $self = shift;
   my $template = shift;

# Obtain the observation number.
   my $num = $self->number;

# Pad with leading zeroes to give a three-digit observation number.
   $num = '0' x ( 3-length( $num ) ) . $num;

# Change the first number.
   $template =~ s/_\d+_/_${num}_/;

# Update the filename using the template.
   $self->file( $template );

}

=back

=head1 SEE ALSO

L<ORAC::Group::GMOS>

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@star.rl.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Science & Technology Facilities Council.
All Rights Reserved.

=cut

1;
