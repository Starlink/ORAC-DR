package ORAC::Bounds;

=head1 NAME

ORAC::Bounds - Provide spatial and/or spectral bounds for files.

=head1 SYNOPSIS

  use ORAC::Bounds qw/ retrieve_bounds update_bounds_headers /;

  my $bounds = retrieve_bounds( $filename );
  update_headers( $filename );

=head1 DESCRIPTION

This package provides functions to retrieve spatial and spectral
information about an NDF containing AST FrameSet information. It
currently retrieves the corners of a bounding box in the spatial
extent, and the upper and lower bounds for the frequency extent.

Bounding information will be incorrect for data encompassing a pole.

=cut

use base qw/ Exporter /;
use vars qw/ $VERSION @EXPORT $DEBUG /;

use Astro::Coords;
use Carp;

use NDF qw/ :ndf :err /;

@EXPORT_OK = qw/ retrieve_bounds return_bounds_header update_bounds_headers /;

=head1 METHODS

=over 4

=item B<retrieve_bounds>

This method retrieve spatial/spectral bounds for a given NDF.

  my $bounds = retrieve_bounds( $file );

The file must be an NDF. The filename need not have the '.sdf' extension.

The return value is a hash reference containing the following keys:

=over 4

=item reference

Astro::Coords object for the reference sky position.

=item top_left

Astro::Coords object for the top left corner of the bounding box.

=item top_right

Astro::Coords object for the top right corner of the bounding box.

=item bottom_left

Astro::Coords object for the bottom left corner of the bounding box.

=item bottom_right

Astro::Coords object for the bottom right corner of the bounding box.

=item frq_sig_lo

Frequency, in gigahertz, of the lower end of the signal sideband.

=item frq_sig_hi

Frequency, in gigahertz, of the upper end of the signal sideband.

=item frq_img_lo

Frequency, in gigahertz, of the lower end of the image sideband.

=item frq_img_hi

Frequency, in gigahertz, of the upper end of the image sideband.

=back

A specific key will be undefined if the given file does not have the
appropriate information to calculate it with. For example, if a file
does not have a SkyFrame, then none of the Astro::Coords objects
listed above will be defined.

This function currently only works on files that have 3D CmpFrames.

=cut

sub retrieve_bounds {
  my $filename = shift;

  my %return;

  return if ! defined $filename;

  if( $filename !~ /\.sdf$/ ) { $filename .= ".sdf"; }

  if( -e $filename ) {

    # Read in the file, get the bounds via ndf_bound, and retrieve the
    # frameset.

    my $STATUS = 0;
    err_begin( $STATUS );
    ndf_begin;
    ndf_find( &NDF::DAT__ROOT(), $filename, my $ndf_id, $STATUS );

    ndf_bound( $ndf_id, 3, my @ndf_lbnd, my @ndf_ubnd, my $ndim, $STATUS );

    # Retrieve the WCS.
    my $wcs = ndfGtwcs( $ndf_id, $STATUS );

    # Finish the NDF handling and deal with errors.
    ndf_annul( $ndf_id, $STATUS );
    ndf_end( $STATUS );

    if( $STATUS != &NDF::SAI__OK ) {
      my ( $oplen, @errs );
      do {
        err_load( my $param, my $parlen, my $opstr, $oplen, $STATUS );
        push @errs, $opstr;
      } until ( $oplen == 1 );
      err_annul( $STATUS );
      err_end( $STATUS );
      croak "Error retrieving WCS from NDF:\n" . join "\n", @errs;
    }
    err_end( $STATUS );

    # Retrieve spatial information.
    my $skytemplate = Starlink::AST::SkyFrame->new( "" );
    $skytemplate->Set( 'MaxAxes' => 3,
                       'MinAxes' => 1 );
    my $skyframe = $wcs->FindFrame( $skytemplate, "" );

    # We want the skyframe system to be ICRS.
    if( defined( $skyframe ) ) {
      $skyframe->Set( 'system' => 'ICRS' );
    }

    # Retrieve spectral information.
    my $spectemplate = Starlink::AST::SpecFrame->new( "" );
    $spectemplate->Set( 'MaxAxes' => 3 );
    my $specframe = $wcs->FindFrame( $spectemplate, "" );

    # We want the units returned in GHz, the system to be frequency,
    # and to use the barycentric standard of rest.
    if( defined( $specframe ) ) {
      $specframe->Set( 'system' => 'FREQ',
                       'unit'   => 'GHz',
                       'stdofrest' => 'BARY',
                     );
    }

    # astTranP uses the GRID coordinate system as a base, which
    # counts from 0.5. We need to find out how big the NDF is, which
    # we can do from the @ndf_lbnd and @ndf_ubnd arrays.
    my @wcs_bnds;
    my @isb_bnds;
    my @ssb_bnds;
    my $x_min = 0.5;
    my $x_max = 0.5 + ( $ndf_ubnd[0] - $ndf_lbnd[0] ) + 1;
    my $y_min = 0.5;
    my $y_max = 0.5 + ( $ndf_ubnd[1] - $ndf_lbnd[1] ) + 1;
    if( defined( $ndf_ubnd[2] ) ) {
      my $z_min = 0.5;
      my $z_max = 0.5 + ( $ndf_ubnd[2] - $ndf_lbnd[2] ) + 1;

      if( defined( $skyframe ) ) {
        @wcs_bnds = $skyframe->TranP( 1,
                                      [ $x_min, $x_min, $x_max, $x_max ],
                                      [ $y_min, $y_max, $y_min, $y_max ],
                                      [ $z_min, $z_min, $z_min, $z_min ] );
      }

      if( defined( $specframe ) ) {

        # Calculate the LSB info.
        $specframe->Set( "SideBand", "observed" );
        @ssb_bnds = $specframe->TranP( 1,
                                       [ $x_min, $x_max ],
                                       [ $y_min, $y_max ],
                                       [ $z_min, $z_max ] );
        # Calculate the USB info.
        $specframe->Set( "SideBand", "image" );
        @isb_bnds = $specframe->TranP( 1,
                                       [ $x_min, $x_max ],
                                       [ $y_min, $y_max ],
                                       [ $z_min, $z_max ] );
      }
    } else {
      @wcs_bnds = $skyframe->Tran2( [ $x_min, $x_min, $x_max, $x_max ],
                                    [ $y_min, $y_max, $y_min, $y_max ],
                                    1 );
    }

    # We now have enough information for the OBSRA/OBSDEC headers.
    if( defined( $skyframe ) ) {

      # Find out which axis is the latitude (declination) and which is
      # the longitude (RA).
      my $lataxis = $skyframe->Get( "LatAxis" );
      my $lonaxis = $skyframe->Get( "LonAxis" );

      my $obsra_rad = $skyframe->Get( "SkyRef($lonaxis)" );
      my $obsdec_rad = $skyframe->Get( "SkyRef($lataxis)" );
      my $obsref = new Astro::Coords( ra => $obsra_rad,
                                      dec => $obsdec_rad,
                                      type => 'J2000',
                                      units => 'radians' );

      $return{'reference'} = $obsref;

      my $obsrabl_rad = $wcs_bnds[0]->[0];
      my $obsratl_rad = $wcs_bnds[0]->[1];
      my $obsrabr_rad = $wcs_bnds[0]->[2];
      my $obsratr_rad = $wcs_bnds[0]->[3];
      my $obsdecbl_rad = $wcs_bnds[1]->[0];
      my $obsdectl_rad = $wcs_bnds[1]->[1];
      my $obsdecbr_rad = $wcs_bnds[1]->[2];
      my $obsdectr_rad = $wcs_bnds[1]->[3];

      my $bl = new Astro::Coords( ra => $obsrabl_rad,
                                  dec => $obsdecbl_rad,
                                  type => 'J2000',
                                  units => 'radians'
                                );
      my $tl = new Astro::Coords( ra => $obsratl_rad,
                                  dec => $obsdectl_rad,
                                  type => 'J2000',
                                  units => 'radians' );
      my $br = new Astro::Coords( ra => $obsrabr_rad,
                                  dec => $obsdecbr_rad,
                                  type => 'J2000',
                                  units => 'radians' );
      my $tr = new Astro::Coords( ra => $obsratr_rad,
                                  dec => $obsdectr_rad,
                                  type => 'J2000',
                                  units => 'radians' );

      $return{'top_left'} = $tl;
      $return{'top_right'} = $tr;
      $return{'bottom_left'} = $bl;
      $return{'bottom_right'} = $br;

    }

    # Only write the sideband bounds if we have them.
    if( defined( $ssb_bnds[0] ) ) {

      $return{'freq_sig_lo'} = ( $ssb_bnds[0]->[0] < $ssb_bnds[0]->[1] ?
                                 $ssb_bnds[0]->[0]                     :
                                 $ssb_bnds[0]->[1]                     );
      $return{'freq_sig_hi'} = ( $ssb_bnds[0]->[0] < $ssb_bnds[0]->[1] ?
                                 $ssb_bnds[0]->[1]                     :
                                 $ssb_bnds[0]->[0]                     );
      $return{'freq_img_lo'} = ( $isb_bnds[0]->[0] < $isb_bnds[0]->[1] ?
                                 $isb_bnds[0]->[0]                     :
                                 $isb_bnds[0]->[1]                     );
      $return{'freq_img_hi'} = ( $isb_bnds[0]->[0] < $isb_bnds[0]->[1] ?
                                 $isb_bnds[0]->[1]                     :
                                 $isb_bnds[0]->[0]                     );
    }


  }

  return \%return;

}

=item B<return_bounds_header>

This function creates an C<Astro::FITS::Header> object which describes
the bounds of the observation in question.

  $header = return_bounds_header( $file );

The file must be an NDF. The '.sdf' extension need not be present.

The following mappings from the keys listed in the retrieve_bounds()
function are made:

=over 4

=item reference -> OBSRA, OBSDEC

=item bottom_left -> OBSRABL, OBSDECBL

=item bottom_right -> OBSRABR, OBSDECBR

=item top_left -> OBSRATL, OBSDECTL

=item top_right -> OBSRATR, OBSDECTR

=item freq_img_lo -> FRQIMGLO

=item freq_img_hi -> FRQIMGHI

=item freq_sig_lo -> FRQSIGLO

=item freq_sig_hi -> FRQSIGHI

=back

If any of the headers already exist, they will be overwritten.

=cut

sub return_bounds_header {
  my $filename = shift;

  return if ! defined $filename;

  if( $filename !~ /\.sdf$/ ) { $filename .= ".sdf"; }

  my $header;

  if( -e $filename ) {

    # Read the current header.
    $header = new Astro::FITS::Header::NDF( File => $filename );

    # Retrieve the bounds.
    my $bounds = retrieve_bounds( $filename );

    # Create  if the specific values are defined.
    if( defined( $bounds->{'reference'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRA',
                                                Value   => $bounds->{'reference'}->ra( format => 'deg' ),
                                                Comment => '[deg] Reference RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDEC',
                                             Value   => $bounds->{'reference'}->dec( format => 'deg' ),
                                             Comment => '[deg] Reference Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    }
    if( defined( $bounds->{'bottom_left'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRABL',
                                                Value   => $bounds->{'bottom_left'}->ra( format => 'deg' ),
                                                Comment => '[deg] Bottom left RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECBL',
                                             Value   => $bounds->{'bottom_left'}->dec( format => 'deg' ),
                                             Comment => '[deg] Bottom left Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    }
    if( defined( $bounds->{'top_left'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRATL',
                                                Value   => $bounds->{'top_left'}->ra( format => 'deg' ),
                                                Comment => '[deg] Top left RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECTL',
                                             Value   => $bounds->{'top_left'}->dec( format => 'deg' ),
                                             Comment => '[deg] Top left Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    }
    if( defined( $bounds->{'bottom_right'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRABR',
                                                Value   => $bounds->{'bottom_right'}->ra( format => 'deg' ),
                                                Comment => '[deg] Bottom right RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECBR',
                                             Value   => $bounds->{'bottom_right'}->dec( format => 'deg' ),
                                             Comment => '[deg] Bottom right Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    }
    if( defined( $bounds->{'top_right'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRATR',
                                                Value   => $bounds->{'top_right'}->ra( format => 'deg' ),
                                                Comment => '[deg] Top right RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECTR',
                                             Value   => $bounds->{'top_right'}->dec( format => 'deg' ),
                                             Comment => '[deg] Top right Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    }
    if( defined( $bounds->{'freq_sig_lo'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQSIGLO',
                                                Value   => $bounds->{'freq_sig_lo'},
                                                Comment => '[GHz] Lower frequency bound, signal sideband',
                                                Type    => 'FLOAT' );
      $header->append( $item );
    }
    if( defined( $bounds->{'freq_sig_hi'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQSIGHI',
                                                Value   => $bounds->{'freq_sig_hi'},
                                                Comment => '[GHz] Upper frequency bound, signal sideband',
                                                Type    => 'FLOAT' );
      $header->append( $item );
    }
    if( defined( $bounds->{'freq_img_lo'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQIMGLO',
                                                Value   => $bounds->{'freq_img_lo'},
                                                Comment => '[GHz] Lower frequency bound, image sideband',
                                                Type    => 'FLOAT' );
      $header->append( $item );
    }
    if( defined( $bounds->{'freq_img_hi'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQIMGHI',
                                                Value   => $bounds->{'freq_img_hi'},
                                                Comment => '[GHz] Upper frequency bound, image sideband',
                                                Type    => 'FLOAT' );
      $header->append( $item );
    }

  }

  return $header;

}

=item B<update_bounds_headers>

This function sets FITS headers in the file describing the bounds of
the observation in question.

  update_bounds_headers( $file );

The file must be an NDF. The '.sdf' extension need not be present.

The following mappings from the keys listed in the retrieve_bounds()
function are made:

=over 4

=item reference -> OBSRA, OBSDEC

=item bottom_left -> OBSRABL, OBSDECBL

=item bottom_right -> OBSRABR, OBSDECBR

=item top_left -> OBSRATL, OBSDECTL

=item top_right -> OBSRATR, OBSDECTR

=item freq_img_lo -> FRQIMGLO

=item freq_img_hi -> FRQIMGHI

=item freq_sig_lo -> FRQSIGLO

=item freq_sig_hi -> FRQSIGHI

=back

If any of the output keys from retrieve_bounds() are undefined, then
the corresponding headers will not be written to the file.

=cut

sub update_bounds_headers {
  my $filename = shift;

  my $header = return_bounds_header( $filename );
  if( defined( $header ) ) {
    $header->writehdr( File => $filename );
  }
}

=head1 SEE ALSO

Starlink::AST, Astro::Coords.

=head1 REVISION

$Id: $

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.  All
Rights Reserved.

=cut

1;
