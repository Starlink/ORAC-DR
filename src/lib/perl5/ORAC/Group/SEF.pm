package ORAC::Group::SEF;

=head1 NAME

ORAC::Group::SEF - Class for dealing with groups based on SEF files

=head1 SYNOPSIS

  use ORAC::Group::SEF

  $Grp = new ORAC::Group::SEF;

=head1 DESCRIPTION

This class rovides implementations of the methods that require
knowledge of the SEF file format rather than generic methods or
methods that require knowledge of a specific instrument.  In general,
the specific instrument sub-classes will inherit from the file type
(which inherits from ORAC::Group) rather than directly from
ORAC::Group. For ING telescopes the group files are based on SEFs and
inherit from this class.

The format specific sub-classes do not contain constructors; they 
should be defined in either the base class or the instrument specific
sub-class.

=cut

use 5.006;
use warnings;
use ORAC::Group;

# Inherit from ORAC::Group
use base qw/ORAC::Group/;

use strict;
use Carp;
use ORAC::Constants qw/:status/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# We need to read SEF files

use Astro::FITS::CFITSIO qw(:constants :longnames);

=head1 PUBLIC METHODS

The following methods are modified from the base class versions.

=head2 General Methods

=over 4

=item B<coaddsread>

Method to read the COADDS information from the group file. If the
Group file exists, the file is opened and the COADDS column is read.

  $Grp->coaddsread;

There are no arguments.

=cut

sub coaddsread {
    my $self = shift;
    my ($status,$fptr,$hdutype,$nrows,$cocol,$coadds,$anynull);

    # Check to see if the file is there

    return (ORAC__ERROR) if (! $self->file_exists);

    # Attempt to open the file

    $status = 0;
    $fptr = Astro::FITS::CFITSIO::open_file($self->file,READONLY,$status);
    return ORAC__ERROR if ($status != 0);

    # Find the table...

    $fptr->movabs_hdu(2,$hdutype,$status);
    if ($status != 0 || ($hdutype != ASCII_TBL && $hdutype != BINARY_TBL)) {
	$fptr->close_file($status);
	return ORAC__ERROR;
    }

    # Find the column and the number of rows...

    $fptr->get_num_rows($nrows,$status);
    $fptr->get_colnum(CASEINSEN,"COADDS",$cocol,$status);
    if ($status != 0 || $nrows == 0) {
	$fptr->close_file($status);
	return ORAC__ERROR;
    }

    # Read the column now...

    $fptr->read_col(TINT,$cocol,1,1,$nrows,"",$coadds,$anynull,$status);
    if ($status != 0) {
	$fptr->close_file($status);
	return ORAC__ERROR;
    }

    # Get out of here...

    $fptr->close_file($status);
    $self->coadds(@$coadds);
    return ORAC__OK;
}

###############

=item B<coaddswrite>

Writes the current contents of coadds() into the current group file().
Returns ORAC__OK if the coadds information was written successfully,
else returns ORAC__ERROR.

  $Grp->coaddswrite;

There are no arguments. The information is written to a FITS table
in the Group file.  If coadds() contains no entries, all
coadds information is removed from the group file if present (and good
status is returned). 

=cut

sub coaddswrite {
    my $self = shift;
    my ($status,$fptr,$hdutype,$nrows,$cocol,@coadds);

    # Check to see if the file is there
  
    return (ORAC__ERROR) unless ($self->file_exists);

    # Open the file...

    $status = 0;
    $fptr = Astro::FITS::CFITSIO::open_file($self->file,READWRITE,$status);
    return (ORAC__ERROR) if ($status != 0);

    # Find the table...

    $fptr->movabs_hdu(2,$hdutype,$status);
    if ($status != 0 || ($hdutype != ASCII_TBL && $hdutype != BINARY_TBL)) {
	$fptr->close_file($status);
	return ORAC__ERROR;
    }

    # Find the column and the number of rows...

    $fptr->get_num_rows($nrows,$status);
    $fptr->get_colnum(CASEINSEN,"COADDS",$cocol,$status);
    if ($status != 0) {
	$fptr->close_file($status);
	return ORAC__ERROR;
    }

    # If there are already some rows, then delete them now...
    
    if ($nrows != 0) {
        $fptr->delete_rows(1,$nrows,$status);
    }
    
    # Write the column now...

    @coadds = $self->coadds;
    $nrows = @coadds;
    $fptr->write_col(TINT,$cocol,1,1,$nrows,"",\@coadds,$status);
    if ($status != 0) {
	$fptr->close_file($status);
	return ORAC__ERROR;
    }

    # Get out of here...

    $fptr->close_file($status);
    return ORAC__OK;
}
    

=item B<erase>

Erases the current group file. 
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

=cut

sub erase {
  my $self = shift;

  my $file = $self->file();
  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;
}

=item B<file_exists>

Checks for the existence of the Group file(). 

=cut

sub file_exists {
  my $self = shift;
  my $file = $self->file;
  if (-e "$file") {
    return 1;
  } else {
    return 0;
  }
}

=item B<readhdr>

Reads the header from the reduced group file (the filename is stored
in the Group object) and sets the Group header. This method sets the
header in the object.

    $Grp->readhdr;

All exisiting header information is lost.  If there is an error during
the read an empty hash is stored in the header.

Currently this method assumes that the reduced group is stored in
SEF format. Only the FITS header is retrieved from the SEF.

There are no input or return arguments.

=cut

sub readhdr {
    my $self = shift;
    my ($fname,$ref,$status,$fptr,$read_status);

    # Get the file name...NB the input parameter can be either a fits file
    # pointer or the file name.

    $fname = (@_ ? shift : $self->file);

    # Initialise the structure.

    %{$self->hdr} = ();

    # Open the file. 

    $status = 0;
    $fptr = Astro::FITS::CFITSIO::open_file($fname,READONLY,$status);

    # If you could open the file, then read the PHU header and tack that
    # into the file object header structure.  If there is an image extension
    # then read that and tack it on

    if ($status == 0) {
        ($ref,$read_status) = read_fits_header($fptr,1);
        %{$self->hdr} = %$ref if ($read_status == 0);
        ($ref,$read_status) = read_fits_header($fptr,2);
        %{$self->hdr} = (%{$self->hdr},%$ref) if ($read_status == 0);
        $fptr->close_file($status);
    }
    
    # Calculate the derived headers

    $self->calc_orac_headers;

    # Get outta here

    return;
}

=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=over 4

=item B<read_fits_header>

Method to read the header items out of the extension of a SEF and put them
into a hash array. Input is a CFITSIO file descriptor and an extension number.
Output is a hash reference to the header items and a CFITSIO status value.

    ($href,$status) = read_fits_header($fptr,$nextn);

=cut

sub read_fits_header {
    my ($fptr,$extn) = @_;
    my ($status,%hdr,$i,$key,$value,$junk,$nhdr,$nleft);

    # Initialise the header hash

    %hdr = ();

    # Get the header space

    $status = 0;
    $fptr->movabs_hdu($extn,$junk,$status); 
    return(\%hdr,$status) if ($status != 0);
    $fptr->get_hdrspace($nhdr,$nleft,$status);

    # Loop over the header

    for ($i = 1; $i <= $nhdr; $i++) {
        last unless $status == 0;
        
        # Read each keyword and store it away

        $fptr->read_keyn($i,$key,$value,$junk,$status);
        $value = $1 if ($value =~/^'\s*(.*?)\s*'$/);
        $hdr{$key} = $value;
    }

    # Return the header and the status

    return(\%hdr,$status);
}

=cut

=back

=head1 REQUIREMENTS

This module requires the L<Astro::FITS::CFITSIO> module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Jim Lewis (jrl@ast.cam.ac.uk)

=head1 COPYRIGHT

Copyright (C) 2003-2006 Cambridge Astronomy Survey Unit
All Rights Reserved.


=cut

1;
