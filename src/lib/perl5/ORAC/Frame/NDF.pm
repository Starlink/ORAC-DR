package ORAC::Frame::NDF;

=head1 NAME

ORAC::Frame::NDF - Class for dealing with frames based on NDF files

=head1 SYNOPSIS

  use ORAC::Frame::NDF

  $Frm = new ORAC::Frame::NDF;

=head1 DESCRIPTION

This class provides implementations of the methods that require
knowledge of the NDF file format rather than generic methods or
methods that require knowledge of a specific instrument.  In general,
the specific instrument sub-classes will inherit from the file type
(which inherits from ORAC::Frame) rather than directly from
ORAC::Frame. For JCMT and UKIRT the group files are based on NDFs and
inherit from this class.

The format specific sub-classes do not contain constructors; they 
should be defined in either the base class or the instrument specific
sub-class.

=cut

use 5.006;
use ORAC::Frame;
use ORAC::Error qw/ :try /;

# Inherit from ORAC::Frame
# BaseNDF is ahead of ORAC::Frame because we need to use readhdr
# from the NDF base rather than the file Base.
use base qw/ORAC::BaseNDF ORAC::Frame /;

use warnings;
use strict;
use Carp;
use ORAC::Constants qw/:status/;
use ORAC::Print;
use Astro::FITS::Header::NDF;
use Starlink::HDSPACK qw/ delete_hdsobj copobj retrieve_locs /;
use NDF;

use vars qw/$VERSION/;

# Special Name of the NDF that contains the HEADER component of an HDS
my $HDR = 'HEADER';

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 PUBLIC METHODS

The following methods are modified from the base class versions.

=head2 General Methods

=over 4

=item B<erase>

Erase the current file from disk.

  $Frm->erase($i);

The optional argument specifies the file number to be erased.
The argument is identical to that given to the file() method.
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

Note that the file() method is not modified to reflect the
fact the the file associated with it has been removed from disk.

This method is usually called automatically when the file()
method is used to update the current filename and the nokeep()
flag is set to true. In this way, temporary files can be removed
without explicit use of the erase() method. (Just need to
use the nokeep() method after the file() method has been used
to update the current filename).

Can support paths to HDS objects. If the last object is removed from
an HDS container file, the entire container file is removed.

=cut

sub erase {
  my $self = shift;

  # Retrieve the necessary frame name
  my $file = $self->file(@_);

  # First we have to decide whether we are removing
  # an HDS object or a file
  my $status;
  if (-e $file) {
    # File exists
    $status = unlink $file;
  } elsif ($file !~ /\./) {
    # No suffix at all, try appending an '.sdf'
    $file .= '.sdf';
    $status = unlink $file;
  } else {
    # Okay, we have dots in the filename and the file
    # does not exist. Assume HDS path
    $status = delete_hdsobj( $file );

    # if this went okay we have to make sure that 
    # we remove the parent file if this has resulted
    # in an empty HDS container. Only worth checking if
    # we have only 1 dot in the name
    my $ndot = ( $file =~ tr[.][.]);

    if ($status && $ndot == 1) {
      # Open the file. Need status.
      my $hdsstat = &NDF::SAI__OK;
      my @bits = split(/\./,$file);
      my $hdsfile = $bits[0];

      # Should we unlink the file?
      my $dounlink = 0;

      # Begin error context
      err_begin($hdsstat);

      # Should probably factor this code out of here and ORAC::Frame::CGS4
      hds_open($hdsfile, 'READ', my $loc, $hdsstat);
      if ($hdsstat == &NDF::SAI__OK) {
	
	# Find out how many we have
	dat_ncomp($loc, my $ncomp, $hdsstat);

	if ($ncomp == 0) {
	  # always unlink if we have nothing left
	  $dounlink = 1;
	} elsif ($ncomp == 1) {
	  # Need to special case when we have a .HEADER
	  # Get locator to component
	  dat_index($loc, 1, my $cloc, $hdsstat);

	  # Find its name
	  dat_name($cloc, my $name, $hdsstat);

	  # Delete file if this is .HEADER
	  $dounlink = 1 if $name eq $HDR;

	  # Release locator
	  dat_annul( $cloc, $hdsstat);

	}

      }

      # Close the file
      dat_annul($loc, $hdsstat);
      print "Should we unlink $hdsfile for $file? $dounlink";
      # Remove the file if HDS status is good
      if ($hdsstat == &NDF::SAI__OK) {
	$hdsfile .= ".sdf";
	$status = unlink($hdsfile) if $dounlink;
      } else {
	# Annul hds status
	err_annul($status);

	# Set status to bad
	$status = 0;
      }

      # End error context
      err_end($hdsstat);

    }

  }

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;

}


=item B<file_exists>

Checks for the existence of the frame file(). Assumes a C<.sdf>
extension.

  $exists = $Frm->exists($i)

The optional argument specifies the file number to be used.
All extension are removed from the file name before adding the
C<.sdf> so that HDS containers can be supported (and files
that already have the extension)  -- but note that
this version of the method does not look inside HDS containers
looking for NDFs.

=cut

sub file_exists {
  my $self = shift;
  my $file = $self->file(@_);

  # Strip anything after the first dot (in case extensions already
  # present)
  $file =~ s/\..*$//;

  # Check for file existence
  if (-e "$file.sdf") {
    return 1;
  } else {
    return 0;
  }
}

=item B<inout>

Method to return the current input filename and the new output
filename given a suffix.  Copes with non-existence of HDS container
and handles NDF subframes on the assumption that any NDF with a
"." in it must be referring to an HDS component.

The suffix is appended to the root filename derived from the characters
before the first ".". Note that this uses the ORAC-DR standard, replacing
the first non-numeric suffix.

The following logic is applied when propogating HDS containers:

 - If a '.' is present

   NFILES > 1
       The new suffix is attached before the dot.
       An HDS container is created (based on the root) to
       receive the expected NDF. If present, a .HEADER component
       is copied to the output file, else, the current FITS header
       is written to a .HEADER component. Note that even if multiple
       HDS component paths are included in the input file, only
       the last section of the path is copied to the output file.
       ie file.A.B.I1 will result in outfile.I1

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

The second (optional) argument is used to specify which of the input
filenames should be used to generate an output name. This number is
forwarded to the file() method and defaults to 1 (ie the first frame).

If a value of 0 is provided, the output name is derived assuming the
NFILES=1 rule described above. This allows the output file name
to be derived correctly in the many-to-one scenario.

=cut

sub inout {

  my $self = shift;

  my $suffix = shift;

  # Read the number
  my $num = 1;
  if (@_) { $num = shift; }

  # if we have been given a zero as the second argument, assume
  # that HDS propogation is not desired.
  my $collapse;
  if ($num == 0) {
    $collapse = 1;
    $num = 1;
  }

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
  if (defined $rest && $nfiles > 1 && !$collapse) {

    # We are only propogating the name with the last part of the HDS path
    # intact
    my $outpath = (split( /\./, $rest ))[-1];

    # Starlink status
    my $status = &NDF::SAI__OK;

    # Begin error context
    err_begin($status);

    # if the container already exists, erase the component with the
    # same root name as we expect to write in
    if (-e $outfile.".sdf") {
      hds_open($outfile, 'UPDATE', my $loc, $status);

      dat_there($loc, $outpath, my $there, $status);
      dat_erase($loc, $outpath, $status) if $there;

      dat_annul($loc, $status);

    } else {
      # output file does not exist so create it and optionally
      # copy in the .HEADER component
      my @null = (0);

      # Create the new HDS container and name the root component after the
      # first 9 characters of the output filename
      hds_new ($outfile,substr($outfile,0,9),"ORACDR_HDS",
	       0,@null,my $loc,$status);
      dat_annul($loc, $status);

      if ($status == &NDF::SAI__OK) {

	# HEADER propogation
	# propagate header if it is there to copy

	# is it there?
	err_mark();
	my $lstat = &NDF::SAI__OK;
	($lstat, my @locators) = retrieve_locs($root. ".$HDR", 'READ',$lstat);
	my $hdrok;
	$hdrok = 1 if $lstat == &NDF::SAI__OK;
	dat_annul( $_, $lstat) for @locators;
	err_annul( $lstat ) if $lstat != &NDF::SAI__OK;
	err_rlse();

	$hdrok = 0;

	if ($hdrok) {
	  $status = copobj($root.".$HDR",$outfile.".header",$status);

	  if ($status != &NDF::SAI__OK) {
	    orac_err("Failed to propagate FITS header to output container!");
	    err_annul( $status );
	  }
	} else {
	  # write our own
	  # open the output file for update
	  hds_open($outfile, 'UPDATE', my $loc, $status);

	  # create the NDF in there
	  ndf_place( $loc, $HDR, my $place, $status);
	  my @ubnd = (1);
	  my @lbnd = (1);
	  ndf_new( '_INTEGER', 1, @lbnd, @ubnd, $place, my $indf, $status);

	  # free the HDS locator
	  dat_annul( $loc, $status );

	  # now need to write some data to it to prevent complaints
	  ndf_map( $indf, 'DATA', '_INTEGER', 'WRITE', my $pntr, my $el,
		   $status);
	  my @data = (1);
	  NDF::array2mem(@data, "i*", $pntr) if $status == &NDF::SAI__OK;

	  ndf_unmap( $indf, 'DATA', $status );

	  # now write the fits header
	  my $fits = $self->fits;

	  # rebless to NDF subclass. This is horrible - the API needs
	  # fixing
	  $fits = bless( $fits, "Astro::FITS::Header::NDF");
	  $fits->writehdr( ndfID => $indf );

	  # close the NDF
	  ndf_annul( $indf, $status );
	}
      } else {
	orac_err("Failed to create HDS output container '$outfile'!")
	  if $status != &NDF::SAI__OK;
	err_annul( $status );
      }
    }

    # end error context
    err_end($status);

    # append the HDS path
    $outfile .= ".".$outpath;
  }

  return (wantarray ? ($infile, $outfile) : $outfile );
}

=back

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::BaseNDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

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
