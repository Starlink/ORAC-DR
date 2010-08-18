package ORAC::Frame::UKIRT;

=head1 NAME

ORAC::Frame::UKIRT - UKIRT class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::UKIRT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to UKIRT. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::UKIRT> objects.

=cut

use 5.006;
use strict;
use warnings;

# Set pattern_from_bits() to be the same as file_from_bits()
*pattern_from_bits = \&file_from_bits;

# A package to describe a UKIRT group object for the
# ORAC pipeline

use vars qw/$VERSION/;
use ORAC::Frame::NDF;
use ORAC::Constants;
use ORAC::Print;

use NDF;
use Starlink::HDSPACK qw/copobj/;

# Let the object know that it is derived from ORAC::Frame::NDF;
use base qw/ORAC::Frame::NDF/;

$VERSION = '1.0';


# standard error module and turn on strict
use Carp;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 General Methods

=over 4

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

The $obsnum is zero padded to 5 digits.

pattern_from_bits() is currently an alias for file_from_bits(),
and both can be used interchangably in the UKIRT subclass.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # Zero pad the number
  $obsnum = sprintf("%05d", $obsnum);

  # UKIRT form is FIXED PREFIX _ NUM SUFFIX
  return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This generic UKIRT version returns back the observation filename (from
file_from_bits) , adds a leading "." and replaces the .sdf with .ok

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # flag files for UKIRT of the type .xYYYYMMDD_NNNNN.ok
  my $raw = $self->file_from_bits($prefix, $obsnum);

  # raw includes the .sdf so we have to strip it
  $raw = $self->stripfname($raw);

  my $flag = ".".$raw.".ok";

}

=item B<inout>

Method to return the current input filename and the new output
filename given a suffix.  Copes with non-existence of HDS container
and handles NDF subframes

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
fooled into thinking that nfiles is greater than 1 (eg by adding a dummy
file name to the frame).

Returns $out in a scalar context:

   $out = $Frm->inout($suffix);

Returns $in and $out in an array context:

   ($in, $out) = $Frm->inout($suffix);

   ($in,$out) = $Frm->inout($suffix,2);

=cut

sub inout {

  my $self = shift;

  my $suffix = shift;

  # Read the number
  my $num = 1;
  if (@_) { $num = shift; }

  my $infile = $self->file($num);

  # Split infile into a root and a tail
  my ($junk, $rest) = $self->_split_fname( $infile );
  my @junk = @$junk;

  # We still need the root name though for the copobj
  my $root = $self->_join_fname( $junk, '');

  # We only want to drop the SECOND underscore. If we only have
  # two components we simply append. If we have more we drop the last
  # This prevents us from dropping the observation number in
  # ro970815_28. Special case numbers.
  if ($#junk > 1 && $junk[-1] !~ /^\d+$/) {
    @junk = @junk[0..$#junk-1];
  }

  # Find out how many files we have
  my $nfiles = $self->nfiles;

  # Now append the suffix to the outfile
  # Need to strip a leading underscore if we are using join_name
  $suffix =~ s/^_//;
  push(@junk, $suffix);
  my $outfile = $self->_join_fname(\@junk, '');

  # If we had a suffix (eg .i1) now need to
  # reattach it and create an HDS container *IF* NFILES is greater than 1
  # If NFILES equals 1 we don't need to do anything
  if (defined $rest && $nfiles > 1) {

    my ($loc,$status);
    $status = &NDF::SAI__OK;

    if (-e $outfile.".sdf") {

      err_begin($status);
      hds_open($outfile, 'UPDATE', $loc, $status);

      dat_there($loc, $rest, my $there, $status);
      if ($there) {
	dat_erase($loc, $rest, $status);
      };

      dat_annul($loc, $status);
      err_end($status);


    } else {

      my @null = (0);

      hds_new ($outfile,substr($outfile,0,9),"MICHELLE_HDS",0,@null,$loc,$status);
      dat_annul($loc, $status);
      orac_err("Failed to create HDS container!") if $status != &NDF::SAI__OK;

      # propagate header
      $status = copobj($root.".header",$outfile.".header",$status);
      orac_err("Failed to propagate header!") if $status != &NDF::SAI__OK;
    }

    $outfile .= ".".$rest;
  }

  return ($infile, $outfile) if wantarray();  # Array context
  return $outfile;                            # Scalar context
}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>, L<ORAC::Frame>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut


1;
