package ORAC::Frame::MEF;

=head1 NAME

ORAC::Frame::MEF - Class for dealing with frames based on single-extension
FITS files.  These can be simple FITS or FITS with a single image extension.

=head1 SYNOPSIS

  use ORAC::Frame::MEF

  $Frm = new ORAC::Frame::MEF;

=head1 DESCRIPTION

This class provides implementations of the methods that require
knowledge of the MEF file format rather than generic methods or
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
use ORAC::BaseFITS;

# Inherit from ORAC::Frame

use base qw/ORAC::BaseFITS ORAC::Frame/;

use warnings;
use strict;
use Carp;
use ORAC::Constants qw/:status/;
use Astro::FITS::CFITSIO qw(:longnames :constants);

use vars qw/$VERSION/;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are modified from the base class versions.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::MEF> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::MEF;
   $Frm = new ORAC::Frame::MEF("file_name");
   $Frm = new ORAC::Frame::MEF("UT","number");

The constructor hard-wires the '.fits' rawsuffix and the
'f' prefix although these can be overriden with the
rawsuffix() and rawfixedpart() methods.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    # Define a hash of items needed above that which is provided in
    # the base class

    my %newitems = (SubFrmNo    => undef,
                    SubFrms     => [],
		    FitsSuffix  => undef
		    );

    # Now call the base class constructor

    my $self = $class->SUPER::new(\%newitems);

    # Configure initial state - could pass these in with
    # the class initialisation hash - this assumes that I know
    # the hash member name

    $self->rawsuffix('.fit');
    $self->rawformat('FITS');
    $self->format('FITS');
    $self->fitssuffix('.fit');

    # If arguments are supplied then we can configure the object
    # Currently the argument will be the filename.
    # If there are two args this becomes a prefix and number
    $self->configure(@_) if @_;

   return $self;

}

=back

=head2 Accessor Methods

The following methods are available for accessing the 'instance' data.

=over 4

=cut

=item B<fitssuffix>

Return or set the file name suffix for the converted FITS files.

    $suffix = $self->fitssuffix;

=cut

sub fitssuffix {
    my $self = shift;
    if (@_) {$self->{FitsSuffix} = shift;}
    return ($self->{FitsSuffix});
}

=item B<subfrmnumber>

Set or retrieve the subframe number (FITS image extension number) that
corresponds to the current Frame object.

    $subfrmnum = $Frm->subfrmnumber;
    $Frm->subfrmnumber(1);

This is called at the configuration stage to set the number

=cut

sub subfrmnumber {
    my $self = shift;
    if (@_) {$self->{SubFrmNo} = shift};
    return($self->{SubFrmNo});
}

=back

=head2 General Methods

=over 4

=item B<file_exists>

Checks for the existence of the frame file().

  $exists = $Frm->file_exists()

Might be nice to incorporate an additional argument to see if a particular
extension exists, but I am too bored to do that just now.

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

=item B<getasubframe>

This method is used to get a subframe for a given PHU.

  $Frm->getasubframe(1);

=cut

sub getasubframe {
    my $self = shift;
    my $frameno = shift;

    my $subFrm = ${$self->{SubFrms}}[$frameno-1];
    return($subFrm);
}

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), findgroup(), findrecipe and findnsubs()
methods are invoked by this command. Arguments are required.  If there
is one argument it is assumed that this is the raw filename. If there
are two arguments the filename is constructed assuming that argument 1
is the prefix and argument 2 is the observation number.

  $Frm->configure("fname");
  $Frm->configure("UT","num");

=cut

sub configure {
    my $self = shift;

    # If two arguments (prefix and number)
    # have to find the raw filename first
    # else assume we are being given the raw filename

    my $fname;
    if (scalar(@_) == 1) {
      my $fnamesref = shift;
      $fname = ( ref $fnamesref ? $fnamesref->[0] : $fnamesref );
    } elsif (scalar(@_) == 2) {
	$fname = $self->pattern_from_bits(@_);
    } else {
	croak 'Wrong number of arguments to configure: 1 or 2 args only';
    }

    # Set the filename

    $self->file($fname);

    # Set the raw data file name

    $self->raw($fname);

    # Populate the header

    $self->readhdr;

    # Right, how many extensions where there?  Get the FITS header structure
    # from this file.  Look at the number of sub-images.

    my $fitsobj = $self->fits;
    my @allextn = $fitsobj->subhdrs;
    my $nsubs = @allextn;

    # If there are no sub-images, then you have a simple fits file here.
    # Create a duplicate of the PHU in the first extension.  This simplifies
    # recipes that loop over all image extensions

    my @subfrms = ();
    if ($nsubs == 0) {
        $self->{SubFrms} = [$self];
        $self->subfrmnumber(0);

    # Otherwise create a Frame object for each of the subframes defined in
    # the FITS header...

    } else {
        foreach my $i (1 .. $nsubs) {
            my $sfname = sprintf("%s[%d]",$fname,$i);
            my $subFrm = $self->new;
            $subFrm->file($sfname);
            $subFrm->raw($sfname);
            $subFrm->fits($allextn[$i-1]);
            $subFrm->subfrmnumber($i);
	    my $a = $self->hdr;
	    delete $$a{'END'};
	    $subFrm->hdr(%$a);
            push @subfrms,$subFrm;
        }
        $self->{SubFrms} = [@subfrms];
        $self->subfrmnumber(0);
    }
    $self->findgroup;
    $self->findrecipe;

    # Return something

    return 1;
}

=item B<findnsubs>

This method returns the number of extensions in a MEF.  Right now no
distinction is made between table and image extensions.  That is something
that will have to be addressed

  $ncomp = $Frm->findnsubs;

Returns the number of extensions not counting the PHU.

=cut

sub findnsubs {
    my $self = shift;
    my $file = shift;
    unless (defined $file) {
        $file = $self->file;
    }

    # If the subframes array has been defined, then get the number from
    # that.

    my $nhdus;
    if (defined $self->{SubFrms}) {
        $nhdus = @{$self->{SubFrms}} + 1;

    # Otherwise open the file and read the number of extensions.

    } else {
        my $status = 0;
        my $fptr = Astro::FITS::CFITSIO::open_file($file,READONLY,$status);
        $fptr->get_num_hdus($nhdus,$status);
        $fptr->close_file($status);
        if ($status != 0) {
            orac_err("Can't open file $file for nsubs or error reading");
            return(0);
        }
    }
    return($nhdus-1);
}

=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are
aware of them.

=over 4

=cut

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

Returns group name from header.  If we cannot find anything sensible,
we return 0.  The group name stored in the object is automatically
updated using this value.

=cut

sub findgroup {

  my $self = shift;

  my $hdrgrp = $self->hdr('GRPNUM');
  my $amiagroup;

  # NB: Test for GRPMEM is not 'T' as it used to be.  FITS header reader
  # now silently converts boolean values to 1 or 0.

  if (!defined $self->hdr('GRPMEM')){
    $amiagroup = 1;
  } elsif ($self->hdr('GRPMEM') eq "1") {
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

1;
