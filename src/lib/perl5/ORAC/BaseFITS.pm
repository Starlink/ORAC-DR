package ORAC::BaseFITS;

=head1 NAME

ORAC::BaseFITS - Base class for FITS file manipulation

=head1 SYNOPSIS

  use base qw/ ORAC::BaseFITS /;


=head1 DESCRIPTION

This class provides base methods for use by classes that need to
manipulate FITS files. For example, C<ORAC::Frame::MEF>.

=cut

use 5.006;
use strict;
use warnings;

use Carp;
use Astro::FITS::Header::CFITSIO;
use ORAC::Error qw/ :try /;

use File::Basename;

# List of possible fits file name suffixes

my @FITSEXTNS = ('.fit','.fits','.fts');

=head1 METHODS

=head2 General Methods

=over 4

=item B<readhdr>

Reads the header from the observation file (the filename is stored in
the object).  This method sets the header in the object (in general
that is done by configure() ).

    $Frm->readhdr;

The filename can be supplied if the one stored in the object
is not required:

    $Frm->readhdr($file);

but the header in $Frm is over-written.
All exisiting header information is lost. The C<calc_orac_headers()>
method is invoked once the header information is read.
If there is an error during the read a reference to an empty hash is 
returned.

If used as a class method, the filename must be supplied
and calc_orac_headers() will not be called.

Returns the C<Astro::FITS::Header> object.

=cut

sub readhdr {

  my $self = shift;

  my $is_class_method = (ref $self ? 0 : 1);

  # get the files
  my @files;
  if (@_) {
    @files = @_;
  } else {
    if (!$is_class_method) {
      @files = $self->files;
    } else {
      croak "Can not call readhdr() as class method without supplying file names";
    }
  }

  my ($ref, $status);

  my $file = (@_ ? shift(@files) : $self->file);

  # Just read the fits header
  my $hdr;
  try {
    $hdr = new Astro::FITS::Header::CFITSIO( File => $file );

    # Mark it suitable for tie with array return of multi-values
    $hdr->tiereturnsref(1);

    # And store it in the object
    $self->fits( $hdr ) unless $is_class_method;
  };

  # calc derived headers
  $self->calc_orac_headers unless $is_class_method;

  return $hdr;
}

=item B<parsefname>

Return the basename of a FITS file, (that is the name of the file without
the .fit, .fits etc. filename extension) as well as the directory, filename
suffix and FITS image extension number.

    ($basename,$dir,$suffix,$extn) = $Frm->parsefname($in);

The argument is optional.  If you supply one, it will extract the basename of
the argument stripping off the extension relevant to the object...

=cut

sub parsefname {
    my $self = shift;

    my $fname = (@_ ? shift : $self->file);
    my ($fname2,$extn);
    if ($fname =~ /^(.*?)\[(\d+)\]/) {
        $extn = $2;
        $fname2 = $1;
    } else {
        $fname2 = $fname;
        undef $extn;
    }
    my ($basename,$dir,$suffix) = fileparse($fname2,@FITSEXTNS);
    return($basename,$dir,$suffix,$extn);
}

=back

=head1 NOTES

This class must be in the class hierarchy ahead of the base frame
class (C<ORAC::BaseFile>) so that the C<readhdr> method is
picked up correctly.

=head1 SEE ALSO

L<ORAC::Frame::MEF>

=head1 REVISION

$Id$

=head1 AUTHORS

Jim Lewis E<lt>jrl@ast.cam.ac.ukE<gt>
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
