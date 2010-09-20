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
use DateTime;
use DateTime::Format::ISO8601;

use base qw/ ORAC::BaseNDF /;

our $VERSION;

$VERSION = '1.0';

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
  if ( $file !~ /\.sdf$/ ) {
    $file .= ".sdf";
  }
  return unless -e $file;

  if ( ! defined( $self->hdr ) || scalar( keys( %{$self->hdr} ) ) == 0 ) {
    $self->readhdr;
  }

  # Get the generic headers from the base class and append RA/Dec/Freq bounds information
  my $header = $self->SUPER::collate_headers( $file );
  my $bounds_header = return_bounds_header( $file );
  my $hdr = $self->readhdr( $file );

  # Store the items so that we only append once for efficiency
  my @toappend;
  @toappend = $bounds_header->allitems if defined $bounds_header;

  # Calculate MJD-OBS and MJD-END from DATE-OBS and DATE-END.
  my $dateobs;
  if ( defined( $self->hdr( "DATE-OBS" ) ) ) {
    $dateobs = DateTime::Format::ISO8601->parse_datetime( $self->hdr( "DATE-OBS" ) );
  } elsif ( defined( $hdr->value( "DATE-OBS" ) ) ) {
    $dateobs = DateTime::Format::ISO8601->parse_datetime( $hdr->value( "DATE-OBS" ) );
  }
  if ( defined( $dateobs ) ) {
    my $mjdobs = new Astro::FITS::Header::Item( Keyword => 'MJD-OBS',
                                                Value   => $dateobs->mjd,
                                                Comment => 'MJD of start of observation',
                                                Type    => 'FLOAT' );
    push( @toappend, $mjdobs );
  }

  my $dateend;
  if ( defined( $self->hdr( "DATE-END" ) ) ) {
    $dateend = DateTime::Format::ISO8601->parse_datetime( $self->hdr( "DATE-END" ) );
  } elsif ( defined( $hdr->value( "DATE-END" ) ) ) {
    $dateend = DateTime::Format::ISO8601->parse_datetime( $hdr->value( "DATE-END" ) );
  }
  if ( defined( $dateend ) ) {
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

  if ( ! $self->is_frame ) {
    my $asnid = $self->asn_id;
    my $asnhdr= new Astro::FITS::Header::Item( Keyword => 'ASN_ID',
                                               Value   => $asnid,
                                               Comment => 'Association Identifier',
                                               Type    => 'STRING' );
    push ( @toappend, $asnhdr );
  }

  # Check to see if the OBSIDSS header exists. If it doesn't, create
  # it.
  if ( ! defined( $self->hdr( "OBSIDSS" ) ) &&
       defined( $self->hdr( "OBSID" ) ) &&
       defined( $self->hdr( "SUBSYSNR" ) ) ) {
    my $obsidss = $self->hdr( "OBSID" ) . "_" . $self->hdr( "SUBSYSNR" );
    $self->hdr( "OBSIDSS", $obsidss );
    my $obsidss_hdr = new Astro::FITS::Header::Item( Keyword => 'OBSIDSS',
                                                     Value   => $obsidss,
                                                     Comment => 'Unique observation subsys identifier',
                                                     Type    => 'STRING' );
    push ( @toappend, $obsidss_hdr );
  }

  $header->append( \@toappend );
  return $header;
}

=item B<asn_id>

Retrieves the group identifier for this frame or group and converts it
to an association identifier.

 $asn_id = $obj->asn_id();

The association id will not be prefixed according to mode since the frame
or group does not know the processing mode.

Returns undef if no association could be identified.

=cut

sub asn_id {
  my $self = shift;
  my $asn_txt = '';

  if ($self->is_frame) {
    $asn_txt = $self->group;
  } else {
    $asn_txt = $self->groupid;
  }
  if (defined $asn_txt) {
    return md5_hex( $asn_txt );
  }
  return;
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
