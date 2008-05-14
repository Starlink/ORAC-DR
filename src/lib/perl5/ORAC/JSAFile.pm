package ORAC::JSAFile;

=head1 NAME

ORAC::JSAFile - Extra file handling for JCMT Science Archive
instruments.

=head1 SYNOPSIS

  use base qw/ ORAC::JSAFile /;

=head1 DESCRIPTION

This class provides sub-classed modules for instruments being stored
in the JCMT Science Archive.

=cut

use 5.006;
use warnings;
use strict;
use Carp;
use Digest::MD5 qw/ md5_hex /;

use ORAC::Bounds qw/ return_bounds_header /;

use base qw/ ORAC::BaseNDF /;

our $VERSION;

'$Revision $ ' =~ /.*:\s(.*)\s\$/ && ( $VERSION = $1 );

=head1 PUBLIC METHODS

The following methods are available in this class:

=head2 Accessor Methods

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

  if( ! defined( $self->hdr ) || scalar( keys( %{$self->hdr} ) ) == 0 ) {
    $self->readhdr;
  }

  # Get the generic headers from the base class and append RA/Dec/Freq bounds information
  my $header = $self->SUPER::collate_headers( $file );
  my $bounds_header = return_bounds_header( $file );

  # Store the items so that we only append once for efficiency
  my @toappend;
  @toappend = $bounds_header->allitems if defined $bounds_header;

  # Calculate MJD-OBS and MJD-END from DATE-OBS and DATE-END.

  if( defined( $self->hdr( "DATE-OBS" ) ) ) {
    my $dateobs = DateTime::Format::ISO8601->parse_datetime( $self->hdr( "DATE-OBS" ) );
    my $mjdobs = new Astro::FITS::Header::Item( Keyword => 'MJD-OBS',
                                                Value   => $dateobs->mjd,
                                                Comment => 'MJD of start of observation',
                                                Type    => 'FLOAT' );
    push( @toappend, $mjdobs );
  }
  if( defined( $self->hdr( "DATE-END" ) ) ) {
    my $dateend = DateTime::Format::ISO8601->parse_datetime( $self->hdr( "DATE-END" ) );
    my $mjdend = new Astro::FITS::Header::Item( Keyword => 'MJD-END',
                                                Value   => $dateend->mjd,
                                                Comment => 'MJD of end of observation',
                                                Type    => 'FLOAT' );
    push( @toappend, $mjdend );
  }

  # Set the ASN_TYPE header. 'obs' is for frames, 'night' is for
  # groups.
  my $asnvalue = ( $self->is_frame ? 'obs' : 'night' );
  my $asntype = new Astro::FITS::Header::Item( Keyword => 'ASN_TYPE',
                                               Value   => $asnvalue,
                                               Comment => 'Time-based selection criterion',
                                               Type    => 'STRING' );
  push(@toappend, $asntype);

  if( ! $self->is_frame ) {
    my $md5 = md5_hex($self->groupid);
    my $asnid = new Astro::FITS::Header::Item( Keyword => 'ASN_ID',
                                               Value   => $md5,
                                               Comment => 'ASN ID checksum',
                                               Type    => 'STRING' );
    push ( @toappend, $asnid );
  }

  $header->append( \@toappend );
  return $header;
}

=back

=head1 SEE ALSO

L<ORAC::BaseFile>, L<ORAC::BaseNDF>

=head1 REVISION

$Id: $

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Science and Technology Facilities Council. All
Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful,but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place,Suite 330, Boston, MA 02111-1307,
USA

=cut

1;
