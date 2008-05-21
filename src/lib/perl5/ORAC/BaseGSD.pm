package ORAC::BaseGSD;

=head1 NAME

ORAC::BaseGSD - Base class for NDF file manipulation

=head1 SYNOPSIS

  use base qw/ ORAC::BaseGSD /;


=head1 DESCRIPTION

This class provides base methods for use by classes that need to
manipulate GSD files. For example, C<ORAC::Frame::GSD> and
C<ORAC::Group::GSD>.

=cut

use 5.006;
use strict;
use warnings;

use Carp;
use Astro::FITS::Header::GSD;
use ORAC::Error qw/ :try /;


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

    $Grp->readhdr($file);

but the header in $Frm is over-written.
All exisiting header information is lost. The C<calc_orac_headers()>
method is invoked once the header information is read.
If there is an error during the read a reference to an empty hash is 
returned.

Currently this method assumes that the reduced group is stored in
GSD format. Only the FITS header is retrieved from the GSD.

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

  # Just read the GSD fits header
  my $hdr;
  try {
    my $hdr = new Astro::FITS::Header::GSD( File => $file );

    # Mark it suitable for tie with array return of multi-values
    $hdr->tiereturnsref(1);

    # And store it in the object
    $self->fits( $hdr ) unless $is_class_method;
  };

  # calc derived headers
  $self->calc_orac_headers unless $is_class_method;

  return $hdr;
}

=back

=head1 NOTES

This class must be in the class hierarchy ahead of the base frame
class (C<ORAC::BaseFile>) so that the C<readhdr> method is
picked up correctly.

=head1 SEE ALSO

L<ORAC::Frame::GSD>, L<ORAC::Group::GSD>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
