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

use vars qw/ $VERSION /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 METHODS

=head2 General Methods

=over 4

=item B<collate_headers>

This method is used to collect all of the modified FITS headers for a
given Frame object and return an updated C<Astro::FITS::Header> object
to be used by the C<sync_headers> method.

  my $header = $Frm->collate_headers( $file );

Takes one argument, the filename for which the header will be
returned.

=cut

sub collate_headers {
  my $self = shift;
  my $file = shift;

  return unless defined( $file );
  if( $file !~ /\.sdf$/ ) { $file .= ".sdf"; }
  return unless -e $file;

  my $header = new Astro::FITS::Header;
  $header->removebyname( 'SIMPLE' );
  $header->removebyname( 'END' );

  # Update the version headers.
  my $pipevers = new Astro::FITS::Header::Item( Keyword => 'PIPEVERS',
                                                Value   => $VERSION,
                                                Comment => 'Pipeline version',
                                                Type    => 'STRING' );
  my $engvers = new Astro::FITS::Header::Item( Keyword => 'ENGVERS',
                                               Value   => 1,
                                               Comment => 'Algorithm engine version',
                                               Type    => 'STRING' );
  $header->append( $pipevers );
  $header->append( $engvers );

  # Insert the PRODUCT header. This comes from the $self->product
  # method. If the return value from this method is undefined, do not
  # insert the header.
  my $product = $self->product;
  if( defined( $product ) ) {
    my $prod = new Astro::FITS::Header::Item( Keyword => 'PRODUCT',
                                              Value   => $product,
                                              Comment => 'Pipeline product',
                                              Type    => 'STRING' );
    $header->append( $prod );
  }

  return $header;
}

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

=item B<sync_headers>

This method is used to synchronize FITS headers with information
stored in e.g. the World Coordinate System.

  $Frm->sync_headers;
  $Frm->sync_headers(1);

This method takes one optional parameter, the index of the file to
sync headers for. This index starts at 1 instead of 0.

Headers are only synced if the value returned by C<allow_header_sync>
is true.

=cut

sub sync_headers {
  my $self = shift;

  return unless $self->allow_header_sync;

  my $index = 0;

  if( @_ ) {
    $index = shift;
  }

  my @files;

  if( $index ) {
    push @files, $self->file( $index );
  } else {
    @files = $self->files;
  }

  foreach my $file ( @files ) {

    if( $file !~ /_(\d)+$/ ) {

      my $newheader = $self->collate_headers( $file );
      my $header = new Astro::FITS::Header::NDF( File => $file );
      $header->append( $newheader );
      $header->writehdr( File => $file );

    }
  }
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
