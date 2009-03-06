package ORAC::Frame::INGRID;

=head1 NAME

ORAC::Frame::INGRID - INGRID class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::INGRID;

  $Frm = new ORAC::Frame::INGRID("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to INGRID. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to B<ORAC::Frame::UKIRT>
objects are available to B<ORAC::Frame::INGRID> objects.

=cut

# A package to describe a INGRID group object for the
# ORAC pipeline

use 5.006;
use warnings;
use ORAC::Frame::CGS4;
use ORAC::Print;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame;
use base  qw/ORAC::Frame::CGS4/;

# NDF module and object-copying task for inout. 
use NDF;
use Starlink::HDSPACK qw/copobj/;

# standard error module and turn on strict
use Carp;
use strict;

use vars qw/$VERSION/;
$VERSION = '1.0';

*pattern_from_bits = \&file_from_bits;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::INGRID object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::INGRID;
   $Frm = new ORAC::Frame::INGRID("file_name");
   $Frm = new ORAC::Frame::INGRID("UT","number");

The constructor hard-wires the '.fit' rawsuffix and the
'' prefix although these can be overriden with the
rawsuffix() and rawfixedpart() methods.

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
   $self->rawfixedpart( 'r' );
   $self->rawsuffix( '.fit' );
   $self->rawformat( 'INGMEF' );

# INGRID is really a single frame instrument
# So this should be "NDF" and we should be inheriting
# from UFTI
   $self->format( 'HDS' );

# If arguments are supplied then we can configure the object
# Currently the argument will be the filename.
# If there are two args this becomes a prefix and number
   $self->configure( @_ ) if @_;

   return $self;
}

=back

=head2 General Methods

=over 4


=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number at the end of the raw data
filename.  For example a number can be extracted from strings of the
form textNNNN.sdf or textNNNN, where NNNN is a number (leading zeroes
are stripped) but not textNNNNtext (number must be followed by a decimal
point or nothing at all).

  $number = $Frm->number;

The return value is -1 if no number can be determined.

As an aside, an alternative approach for this method (especially
in a sub-class) would be to read the number from the header.

=cut

sub number {
   my $self = shift;

   my $number = $self->hdr( "RUN" );
   if ( !defined $number ) {
      $number = -1;
   }

   return $number;
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts.  A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

INGRID file name convention is

  rNNNNNN.fit

where NNNNNN is the observation number. e.g

  r597816.fit

pattern_from_bits() is currently an alias for file_from_bits(),
and the two may be used interchangably for INGRID.

=cut

sub file_from_bits {
   my $self = shift;

   my $prefix = shift;
   my $obsnum = shift;

# INGRID naming.
   return $self->rawfixedpart . $obsnum . $self->rawsuffix;
}

=item B<inout>

Method to return the current input filename and the new output
filename given a suffix.  Copes with non-existence of HDS container
and handles NDF subframes.

The following logic is applied:

 - If a '.' is present

   NFILES > 1
       The new suffix is attached before the dot.
       An HDS container is created (based on the root) to
       receive the expected NDF.

   NFILES = 1
       We remove the dot and append the suffix as normal
       (by removing the old suffix first).
       This ensures that when NFILES=1 we will no longer
       be using HDS containers

 - If no '.' is present

       This is the standard behaviour. Simply remove after
       last underscore and replace with new suffix.

If you want to retain the HDS container syntax, this routine has to be
fooled into thinking that nfiles is greater than 1 (e.g. by adding a dummy
file name to the frame).

Returns $out in a scalar context:

   $out = $Frm->inout($suffix);

Returns $in and $out in an array context:

   ($in, $out) = $Frm->inout($suffix);

   ($in, $out) = $Frm->inout($suffix,2);

=cut

sub inout {

   my $self = shift;
   my $suffix = shift;

# Read the number.
   my $num = 1; 
   if (@_) { $num = shift; }

   my $infile = $self->file($num);

# Split infile into a root and a tail.
   my ( $junk, $rest ) = $self->_split_fname( $infile );
   my @junk = @$junk;

# We still need the root name though for the copobj.
   my $root = $self->_join_fname( $junk, '');

# We only want to drop the SECOND underscore.  If we only have
# two components we simply append.  If we have more we drop the
# last.  This prevents us from dropping the observation number in
# ro970815_28.  Special case numbers.
   if ($#junk > 0 && $junk[-1] !~ /^\d+$/) {
     @junk = @junk[0..$#junk-1];
  }

# Find out how many files we have.
   my $nfiles = $self->nfiles;

# Now append the suffix to the outfile.  We need to strip a leading
# underscore if we are using join_name.
   $suffix =~ s/^_//;
   push( @junk, $suffix );
   my $outfile = $self->_join_fname( \@junk, '' );

# If we had a suffix (e.g. .I1) now need to re-attach it and create
# an HDS container *IF* NFILES is greater than 1.  If NFILES equals 1
# we don't need to do anything.
   if ( defined $rest && $nfiles > 1 ) {

      my ( $loc, $status );
      $status = &NDF::SAI__OK;

      if ( -e $outfile.".sdf" ) {

        err_begin( $status );
        hds_open( $outfile, 'UPDATE', $loc, $status );

        dat_there( $loc, $rest, my $there, $status );
        if ( $there ) {
           dat_erase( $loc, $rest, $status );
        };

        dat_annul( $loc, $status );
        err_end( $status );

      } else {

         my @null = ( 0 );

         hds_new ( $outfile, substr( $outfile, 0, 9 ), "MICHELLE_HDS", 0, @null, $loc, $status );
         dat_annul( $loc, $status );
         orac_err( "Failed to create HDS container!" ) if $status != &NDF::SAI__OK;

# Propagate the header.
         $status = copobj( $root.".header", $outfile.".header", $status );
         orac_err( "Failed to propagate header!" ) if $status != &NDF::SAI__OK;
      }

      $outfile .= "." . $rest;
   }

   return ( $infile, $outfile ) if wantarray();  # Array context
   return $outfile;                              # Scalar context
}

sub mergehdr {

}

sub template {
   my $self = shift;
   my $template = shift;

   my $num = $self->number;

# Change the first number.
   $template =~ s/\d+_/${num}_/;

# Update the filename.
   $self->file( $template );

}

=back

=head1 SEE ALSO

L<ORAC::Frame::CGS4>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Science and Technology Facilities Council.
Copyright (C) 1998-2007 Particle Physics and Astronomy Research
Council. All Rights Reserved.

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
