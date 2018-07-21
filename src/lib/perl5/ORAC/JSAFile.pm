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
use ORAC::Print;
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

  # readhdr() triggers a recalculation of uhdr() which we do not want to trigger
  # when we are simply trying to read the basic header. So we create a new
  # object.
  my $newobj = $self->new();
  my $hdr = $newobj->readhdr( $file );

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

  # Check whether BWMODE is missing, i.e. we defined it but it isn't in the
  # file.
  if (defined $self->hdr('BWMODE') and not defined $hdr->value('BWMODE')) {
    orac_warn("BWMODE defined but missing from data. Adding to synced headers.\n");
    push @toappend, new Astro::FITS::Header::Item(
        Keyword => 'BWMODE',
        Value => $self->hdr('BWMODE'),
        Comment => 'ACSIS total bandwidth set up',
        Type => 'STRING',
    );
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

The ASN_ID can be overridden by supplying it as an argument

 $obj->asn_id( $asnid );

=cut

sub asn_id {
  my $self = shift;
  my $asn_txt = '';

  return $self->{ASN_ID} = shift if @_;

  # Return it if we have it
  return $self->{ASN_ID} if defined $self->{ASN_ID};

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

=item B<product_id>

Retrieves the product identifier. This is a combination
of the current product and the subsystem.  In some cases
the first part of the product ID should not be based on
the current product by default.  In this case the
set_product_id_prefix method can be used to set an alternative
which is used in preference to the product.

 $productID = $obj->product_id();

For a Group the product ID is calculated from the first
Frame in the group.

An optional argument can be supplied to override the
internal product() value. This is sometimes required
when the product is about to be updated in the object
but has not yet been updated.

 $productID = $obj->product_id( $product );

=cut

sub product_id {
  my $self = shift;
  my $product = shift;

  # Get the current product if we did not have an override or a set
  # product ID prefix.
  $product //= $self->get_product_id_prefix() // $self->product();

  # Get the subsystem identifier
  my $subsys;
  if ($self->is_frame) {
    $subsys = $self->subsystem_id();
  } else {
    # Could be a subsystem_id() method in ORAC::Group
    # if we feel that the concept is useful. If a subsystem_id()
    # method is added to the base class of ORAC::Frame we should
    # add it to ORAC::Group
    my @all = $self->allmembers;
    my $Frm = shift(@all);
    $subsys = $Frm->subsystem_id();
  }

  return $product . "-" . $subsys;
}

=item B<set_product_id_prefix>

Sets the current product ID prefix.

=cut

sub set_product_id_prefix {
  my $self = shift;
  $self->{'Product_ID_Prefix'} = shift;
}

=item B<get_product_id_prefix>

Gets the current product ID prefix.

=cut

sub get_product_id_prefix {
  my $self = shift;
  return $self->{'Product_ID_Prefix'};
}

=item B<jsa_filename_bits>

Get or set the number of "bits" to keep in filenames. JSA filenames
are troublesome for the standard inout methods.  However we know that
JSA filenames normally follow the pattern:

E<lt>prefixE<gt>E<lt>dateE<gt>_E<lt>obsE<gt>_E<lt>subsysE<gt>_E<lt>productE<gt>_...

So we normally want to keep the first three components, which is the
number this method returns by default, and then add the new product name.

=cut

sub jsa_filename_bits {
  my $self = shift;

  return $self->{'JSA_FN_BITS'} = shift if @_;

  return $self->{'JSA_FN_BITS'} // 3;
}

=back

=head2 General Methods

=over 4

=item B<inout_jsatile>

A variation of the frame C<inout> method for use with files which should
be named based on their JSA tile number.  The tile number is found using
the TILENUM header.

    my ($in, $out) = $Frm->inout_jsatile('suffix', $i + 1);

=cut

sub inout_jsatile {
  my $self = shift;
  my $suffix = shift; $suffix =~ s/^_//;
  my $i = (shift) - 1;

  my $tile = $self->hdrval('TILENUM', $i);
  my $in = $self->file($i + 1);

  orac_term('No TILENUM header found for ' . $in)
    unless defined $tile;

  # Since this class doesn't inherit from another class implementing
  # an inout method, we can't use SUPER to call another.  Therefore
  # implement a simple one, but use knowledge of expected JSA filenames
  # to set the number of filename bits to keep.

  my ($bits, $extn) = $self->_split_fname($in);
  my $nbit = $self->jsa_filename_bits();

  pop @$bits while $nbit < scalar @$bits;
  push @$bits, sprintf('%s%06d', $suffix, $tile);

  my $out = $self->_join_fname($bits, $extn);

  return $out unless wantarray;
  return ($in, $out);
}

=item B<jsa_pub_asn_id>

Method to determine the JCMT Science Archive association identifer
for use in "public" products.  Must be provided by subclasses.

=cut

sub jsa_pub_asn_id {
  die 'jsa_pub_asn_id must be implemented by subclasses of JSAFile';
}

=back

=head1 SEE ALSO

L<ORAC::BaseFile>, L<ORAC::BaseNDF>

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
