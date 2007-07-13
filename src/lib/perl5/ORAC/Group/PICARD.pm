package ORAC::Group::PICARD;

=head1 NAME

ORAC::Group::PICARD - Class for handling groups of reduced data files via PICARD

=head1 SYNOPSIS

=head1 DESCRIPTION

This module provides methods for handling collections of frame objects that are
derived from standalone data products suitable for processing with
PICARD.

=cut

use 5.006;
use warnings;
use vars qw/$VERSION/;

# Let the object know that it is derived from ORAC::Frame::NDF;
use base qw/ORAC::Group::NDF/;

# standard error module and turn on strict
use Carp;
use strict;
use ORAC::Print;

$VERSION = sprintf("%d", q$Revision: 7007 $ =~ /(\d+)/);

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group::NDF>.

=head2 General Methods

=over 4

=item B<file_from_bits>

Filenames can not be constructed from UT date or observation
number because these can not be guaranteed to be available
(although DATE-OBS is parseble for standards compliant data).

Returns a filename of the form pgNNNNN where NNNNN is a zero-padded number
that ensures it does not clash with a previous run of the pipeline
in that directory.

Requires that the application is already chdir'ed to the output
directory. If there are many files in the output directory things
will be a little slow.

=cut

sub file_from_bits {
  my $self = shift;

  opendir(my $DH, File::Spec->curdir)
    or orac_throw("Unable to open current directory for read");
  my @files = grep { /^pg\d\d\d\d\d\./ } readdir($DH);
  closedir($DH);

  # Sort the files in numeric order
  my %indexed;
  for my $file (@files) {
    if ($file =~ /^pg(\d+)\./) {
      my $num = $1;
      $num =~ s/^0+//; # trim leading zeroes
      $indexed{$num} = $file;
    } else {
      orac_throw("Internal error parsing number in '$file'");
    }
  }
  my @sorted = sort { $a <=> $b } keys %indexed;

  my $max = (@sorted ? $sorted[-1] : 0);

  orac_throw("Unable to create a group output file because we have run out of digits\n")   if ($max == 99999);

  # Get the next number
  $max++;

  return sprintf("pg%05d", $max); 

}

=back

=head1 SEE ALSO

L<ORAC::Frame::PICARD>

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

$Id$

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
