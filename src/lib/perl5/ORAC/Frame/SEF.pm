package ORAC::Frame::SEF;

=head1 NAME

ORAC::Frame::SEF - Class for dealing with frames based on single-extension
FITS files.  These can be simple FITS or FITS with a single image extension.

=head1 SYNOPSIS

  use ORAC::Frame::SEF

  $Frm = new ORAC::Frame::SEF;

=head1 DESCRIPTION

This class provides implementations of the methods that require
knowledge of the SEF file format rather than generic methods or
methods that require knowledge of a specific instrument.  In general,
the specific instrument sub-classes will inherit from the file type
(which inherits from ORAC::Frame) rather than directly from
ORAC::Frame. 

The format specific sub-classes do not contain constructors; they 
should be defined in either the base class or the instrument specific
sub-class.

=cut

use 5.006;
use ORAC::Frame;

# Inherit from ORAC::Group

use base qw/ORAC::Frame/;

use warnings;
use strict;
use Carp;
use ORAC::Constants qw/:status/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# We need to read FITS files

use Astro::FITS::CFITSIO qw(:longnames :constants);

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

=cut

sub erase {
  my $self = shift;

  # Retrieve the necessary frame name
  my $file = $self->file(@_);

  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;

}

=item B<basename>

Return the basename of a FITS file, that is the name of the file without
the .fit, .fits etc. filename extension.

    $basename = $Frm->basename($in);

The argument is optional.  If you supply one, it will extract the basename of
the argument stripping off the extension relevant to the object...

=cut

sub basename {
    my $self = shift;

    my $fname = (@_ ? shift : $self->file);
    my $suff = $self->rawsuffix;
    $fname =~ s/^(.*?)($suff)$/$1/;
    return($fname);
}
    
    
=item B<file_exists>

Checks for the existence of the frame file(). 

  $exists = $Frm->exists($i)

The optional argument specifies the file number to be used.

=cut

sub file_exists {
    my $self = shift;
    my $file = $self->file(@_);

    # Check for file existence
    if (-e $file) {
	return 1;
    } else {
	return 0;
    }
}

=item B<readhdr>

Reads the header from the observation file (the filename is stored in
the object).  This method sets the header in the object (in general
that is done by configure() ).

    $Frm->readhdr;

The filename can be supplied if the one stored in the object
is not required:

    $Frm->readhdr($file);

but the header in $Frm is over-written.
All exisiting header information is lost. The calc_orac_headers()
method is invoked once the header information is read.
If there is an error during the read a reference to an empty hash is 
returned.

There are no return arguments.

=cut

sub readhdr {
    my $self = shift;
    my ($fname,$ref,$status,$fptr,$read_status);

    # Get the file name...NB the input parameter can be either a fits file
    # pointer or the file name.

    $fname = (@_ ? shift : $self->file);

    # Initialise the structure.

    %{$self->{Header}} = ();

    # Open the file. 

    $status = 0;
    $fptr = Astro::FITS::CFITSIO::open_file($fname,READONLY,$status);

    # If you could open the file, then read the PHU header and tack that
    # into the file object header structure.  If there is an image extension
    # then read that and tack it on

    if ($status == 0) {
        ($ref,$read_status) = read_fits_header($fptr,1);
        %{$self->{Header}} = %$ref if ($read_status == 0);
        ($ref,$read_status) = read_fits_header($fptr,2);
        %{$self->{Header}} = (%{$self->{Header}},%$ref) if ($read_status == 0);
        $fptr->close_file($status);
    }
    
    # Calculate the derived headers

    $self->calc_orac_headers;

    # Get outta here

    return;
}

=item B<fits_extn>
=cut

sub fitsextn {
    my $self = shift;

    return("fit");
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

sub update_header {
    my $self = shift;
    my ($key,$type,$value,$comment) = @_;

    # Get the file and open it...

    my $status = 0;
    my $fptr = Astro::FITS::CFITSIO::open_file($self->file,READWRITE,$status);
    return($status) if ($status);

    # Now update the keyword...

    $fptr->update_key($type,$key,$value,$comment,$status);
    $fptr->close_file($status);
    $self->hdr($key => $value);
    $self->uhdr($key => $value);
    return($status);
}


=item B<findgroup>

Returns group name from header.  If we can't find anything sensible,
we return 0.  The group name stored in the object is automatically
updated using this value.

=cut

sub findgroup {

  my $self = shift;

  my $hdrgrp = $self->hdr('GRPNUM');
  my $amiagroup;

  if ($self->hdr('GRPMEM') eq "T") {
    $amiagroup = 1;
  } elsif (!defined $self->hdr('GRPMEM')){
    $amiagroup = 1;
  } else {
    $amiagroup = 0;
  }

  # Is this group name set to anything useful
  if (!$hdrgrp || !$amiagroup ) {
    # if the group is invalid there is not a lot we can do
    # so we just assume 0
    $hdrgrp = 0;
  }

  $self->group($hdrgrp);

  return $hdrgrp;

}


=back

=head1 REQUIREMENTS

Currently this module requires the L<Astro::FITS::CFITSIO> module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Jim Lewis (jrl@ast.cam.ac.uk)

=head1 COPYRIGHT

Copyright (C) 2003-2006 Cambridge Astronomy Survey Unit. All Rights Reserved.

=cut
#
#
# $Log$
# Revision 1.1  2003/01/22 11:46:21  jrl
# Initial entry
#
#
#
 
1;
