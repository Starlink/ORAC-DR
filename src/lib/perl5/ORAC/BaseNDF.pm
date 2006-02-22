package ORAC::BaseNDF;

=head1 NAME

ORAC::BaseNDF - Base class for NDF file manipulation

=head1 SYNOPSIS

  use base qw/ ORAC::BaseNDF /;


=head1 DESCRIPTION

This class provides base methods for use by classes that need to
manipulate NDF files. For example, C<ORAC::Frame::NDF> and
C<ORAC::Group::NDF>.

=cut

use 5.006;
use strict;
use warnings;

use Astro::FITS::Header::NDF;
use ORAC::Error qw/ :try /;
use ORAC::Constants qw/ :status /;
use ORAC::Print;

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
NDF format. Only the FITS header is retrieved from the NDF.

There are no return arguments.

=cut

sub readhdr {

  my $self = shift;

   my ($ref, $status);

  my $file = (@_ ? shift : $self->file);

  my $Error;

  # Just read the NDF fits header
  try {
    my $hdr = new Astro::FITS::Header::NDF( File => $file );

    # Mark it suitable for tie with array return of multi-values
    $hdr->tiereturnsref(1);

    # And store it in the object
    $self->fits( $hdr );
  } otherwise {
    $Error = shift;
  };
  if( defined( $Error ) ) {
    ORAC::Error->flush;
    throw ORAC::Error::FatalError( "$Error" );
  };

  # calc derived headers
  $self->calc_orac_headers;

  return;
}



=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=over 4

=item B<stripfname>

Method to strip file extensions from the filename string. This method
is called by the file() method. We strip all extensions of the
form ".sdf", ".sdf.gz" and ".sdf.Z" since Starlink tasks do not require
the extension when accessing the file name if Convert has been
started.

=cut

sub stripfname {

  my $self = shift;

  my $name = shift;

  # Strip everything after the first dot
  $name =~ s/\.(sdf)(\.gz|\.Z)?$//
    if defined $name;

  return $name;
}

=back

=head1 NOTES

This class must be in the class hierarchy ahead of the base frame
class (C<ORAC::BaseFile>) so that the C<readhdr> method is
picked up correctly.

=head1 SEE ALSO

L<ORAC::Frame::NDF>, L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
