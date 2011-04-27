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

use strict;
use warnings;

use base qw/ Exporter /;
use vars qw/ $VERSION @EXPORT_OK $DEBUG /;

$VERSION = '1.0';
$DEBUG = 0;

use Astro::FITS::Header::NDF;
use Astro::Coords;
use Starlink::AST 1.01;
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

=item centre

Astro::Coords object for the central pixel in the NDF.

=item frq_sig_lo

Barycentric frequency, in gigahertz, of the lower end of the signal sideband.

=item frq_sig_hi

Barycentric frequency, in gigahertz, of the upper end of the signal sideband.

=item frq_img_lo

Barycentric frequency, in gigahertz, of the lower end of the image sideband.

=item frq_img_hi

Barycentric frequency, in gigahertz, of the upper end of the image sideband.

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

  if ( $filename !~ /\.sdf$/ ) {
    $filename .= ".sdf";
  }

  if ( -e $filename ) {

    # Read in the file, get the bounds via ndf_bound, and retrieve the
    # frameset.
    my $STATUS = 0;
    err_begin( $STATUS );
    ndf_begin;
    ndf_find( &NDF::DAT__ROOT(), $filename, my $ndf_id, $STATUS );

    ndf_bound( $ndf_id, 7, my @ndf_lbnd, my @ndf_ubnd, my $ndim, $STATUS );

    # Retrieve the WCS.
    my $wcs = ndfGtwcs( $ndf_id, $STATUS );

    # Read the FITS header
    my $fitshdr = Astro::FITS::Header::NDF->new( ndfID => $ndf_id );
    my $tracksys = $fitshdr->value("TRACKSYS");

    # Finish the NDF handling and deal with errors.
    ndf_annul( $ndf_id, $STATUS );
    ndf_end( $STATUS );

    if ( $STATUS != &NDF::SAI__OK ) {
      my @errs = err_flush_to_string( $STATUS );
      err_end( $STATUS );
      croak "Error retrieving WCS from NDF:\n" . join "\n", @errs;
    }
    err_end( $STATUS );

    # Try to find the spectral and spatial bounds
    my %return = (
                  calc_spectral_bounds( $wcs, \@ndf_lbnd, \@ndf_ubnd ),
                  calc_spatial_corners( $wcs, \@ndf_lbnd, \@ndf_ubnd )
                 );

    # If this is a moving source blank the reference position
    # if we do not have a tracking system we play it safe by not blanking
    # the reference.
    delete $return{reference}
      if (defined $tracksys && ($tracksys eq 'APP' || $tracksys eq 'AZEL'));

    return \%return;
  }
  return ();
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

  if ( $filename !~ /\.sdf$/ ) {
    $filename .= ".sdf";
  }

  my $header;

  if ( -e $filename ) {

    # Read the current header.
    $header = new Astro::FITS::Header( File => $filename );
    $header->removebyname( 'SIMPLE' );
    $header->removebyname( 'END' );

    # Retrieve the bounds.
    my $bounds = retrieve_bounds( $filename );

    # Create  if the specific values are defined.
    if ( defined( $bounds->{'reference'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRA',
                                                Value   => $bounds->{'reference'}->ra( format => 'deg' ),
                                                Comment => '[deg] Reference ICRS RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDEC',
                                             Value   => $bounds->{'reference'}->dec( format => 'deg' ),
                                             Comment => '[deg] Reference ICRS Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRA',
                                                Value   => undef,
                                                Comment => '[deg] Reference ICRS RA coordinate',
                                                Type    => 'UNDEF' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDEC',
                                             Value   => undef,
                                             Comment => '[deg] Reference ICRS Dec coordinate',
                                             Type    => 'UNDEF' );
      $header->append( $item );
    }

    if ( defined( $bounds->{'bottom_left'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRABL',
                                                Value   => $bounds->{'bottom_left'}->ra( format => 'deg' ),
                                                Comment => '[deg] Bottom left ICRS RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECBL',
                                             Value   => $bounds->{'bottom_left'}->dec( format => 'deg' ),
                                             Comment => '[deg] Bottom left ICRS Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRABL',
                                                Value   => undef,
                                                Comment => '[deg] Bottom left ICRS RA coordinate',
                                                Type    => 'UNDEF' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECBL',
                                             Value   => undef,
                                             Comment => '[deg] Bottom left ICRS Dec coordinate',
                                             Type    => 'UNDEF' );
    }

    if ( defined( $bounds->{'top_left'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRATL',
                                                Value   => $bounds->{'top_left'}->ra( format => 'deg' ),
                                                Comment => '[deg] Top left ICRS RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECTL',
                                             Value   => $bounds->{'top_left'}->dec( format => 'deg' ),
                                             Comment => '[deg] Top left ICRS Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRATL',
                                                Value   => undef,
                                                Comment => '[deg] Top left ICRS RA coordinate',
                                                Type    => 'UNDEF' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECTL',
                                             Value   => undef,
                                             Comment => '[deg] Top left ICRS Dec coordinate',
                                             Type    => 'UNDEF' );
    }

    if ( defined( $bounds->{'bottom_right'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRABR',
                                                Value   => $bounds->{'bottom_right'}->ra( format => 'deg' ),
                                                Comment => '[deg] Bottom right ICRS RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECBR',
                                             Value   => $bounds->{'bottom_right'}->dec( format => 'deg' ),
                                             Comment => '[deg] Bottom right ICRS Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRABR',
                                                Value   => undef,
                                                Comment => '[deg] Bottom right ICRS RA coordinate',
                                                Type    => 'UNDEF' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECBR',
                                             Value   => undef,
                                             Comment => '[deg] Bottom right ICRS Dec coordinate',
                                             Type    => 'UNDEF' );
      $header->append( $item );
    }

    if ( defined( $bounds->{'top_right'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRATR',
                                                Value   => $bounds->{'top_right'}->ra( format => 'deg' ),
                                                Comment => '[deg] Top right ICRS RA coordinate',
                                                Type    => 'FLOAT' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECTR',
                                             Value   => $bounds->{'top_right'}->dec( format => 'deg' ),
                                             Comment => '[deg] Top right ICRS Dec coordinate',
                                             Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'OBSRATR',
                                                Value   => undef,
                                                Comment => '[deg] Top right ICRS RA coordinate',
                                                Type    => 'UNDEF' );
      $header->append( $item );

      $item = new Astro::FITS::Header::Item( Keyword => 'OBSDECTR',
                                             Value   => undef,
                                             Comment => '[deg] Top right ICRS Dec coordinate',
                                             Type    => 'UNDEF' );
    }

    if ( defined( $bounds->{'freq_sig_lo'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQSIGLO',
                                                Value   => $bounds->{'freq_sig_lo'},
                                                Comment => '[GHz] Lower barycentric freq bound, signal sideband',
                                                Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQSIGLO',
                                                Value   => undef,
                                                Comment => '[GHz] Lower barycentric freq bound, signal sideband',
                                                Type    => 'UNDEF' );
      $header->append( $item );
    }

    if ( defined( $bounds->{'freq_sig_hi'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQSIGHI',
                                                Value   => $bounds->{'freq_sig_hi'},
                                                Comment => '[GHz] Upper barycentric freq bound, signal sideband',
                                                Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQSIGHI',
                                                Value   => undef,
                                                Comment => '[GHz] Upper barycentric freq bound, signal sideband',
                                                Type    => 'UNDEF' );
      $header->append( $item );
    }

    if ( defined( $bounds->{'freq_img_lo'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQIMGLO',
                                                Value   => $bounds->{'freq_img_lo'},
                                                Comment => '[GHz] Lower barycentric freq bound, image sideband',
                                                Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQIMGLO',
                                                Value   => undef,
                                                Comment => '[GHz] Lower barycentric freq bound, image sideband',
                                                Type    => 'UNDEF' );
      $header->append( $item );
    }

    if ( defined( $bounds->{'freq_img_hi'} ) ) {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQIMGHI',
                                                Value   => $bounds->{'freq_img_hi'},
                                                Comment => '[GHz] Upper barycentric freq bound, image sideband',
                                                Type    => 'FLOAT' );
      $header->append( $item );
    } else {
      my $item = new Astro::FITS::Header::Item( Keyword => 'FRQIMGHI',
                                                Value   => undef,
                                                Comment => '[GHz] Upper barycentric freq bound, image sideband',
                                                Type    => 'UNDEF' );
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
  if ( defined( $header ) ) {
    $header->writehdr( File => $filename );
  }
}

=back

=begin _HELPER_ROUTINES_

=head1 HELPER ROUTINES

=over 4

=item B<calc_spectral_bounds>

Given a frameset, extract the specframe and return a list
in the form of a hash with the high and low values in the
observed and, if relevant, image sideband.

  %bounds = calc_spectral_bounds( $frameset, \@lbnd, \@ubnd );

Where the second and third arguments are the lower and upper
pixel bounds of the data array.

=cut

sub calc_spectral_bounds {
  my $fset = shift;
  my $lbnd = shift;
  my $ubnd = shift;

  # The template can be a SpecFrame since that matches a DSBSpecFrame
  my ($fsout, $outax) = get_frameset_via_template( $fset,
                                                   Starlink::AST::SpecFrame->new( "MaxAxes=100" ),
                                                 );
  return unless defined $fsout;
  return unless $fsout->HasAttribute( "StdofRest" ); # Defensive

  # Make sure we have the right attributes
  $fsout->Set( 'system' => 'FREQ',
               'unit'   => 'GHz',
               'stdofrest' => 'BARY',
             );

  # Now we can ask for the bounds (we are 1D so it is easy)
  # and we know which pixel axis to use
  my $dims = $ubnd->[ $outax->[0] - 1 ] - $lbnd->[ $outax->[0] - 1 ] + 1;
  my @speclbnd = ( 0.5 );
  my @specubnd = ( $dims + 0.5 );

  # See if we have the Sideband attribute
  my $has_dsb = $fsout->HasAttribute( "Sideband" );

  # Force Observed sideband
  $fsout->Set( "Sideband" => "Observed" ) if $has_dsb;

  my %results;
  for my $type (qw/ sig img / ) {
    my ($low, $high, $lout, $uout) = $fsout->MapBox( \@speclbnd,
                                                     \@specubnd,
                                                     1, 1 );
    $results{"freq_${type}_lo"} = $low;
    $results{"freq_${type}_hi"} = $high;

    last unless $has_dsb;
    $fsout->Set( "Sideband" => "Image" );
  }

  return %results;
}

=item B<calc_spatial_corners>

Given a frameset, extract the skyframe and return a list
in the form of a hash with the coordinates of the "corners"
of the data array. The bounding box is not calculated.

  %bounds = calc_spatial_corners( $frameset, \@lbnd, \@ubnd );

Where the second and third arguments are the lower and upper
pixel bounds of the data array.

Note that these corners refer to the pixel centre, not the further
extent of the pixel.

Also calculates the centre (key = centre) and retrieves
any reference coordinate (key = reference)

=cut

sub calc_spatial_corners {
  my $fset = shift;
  my $lbnd = shift;
  my $ubnd = shift;

  # Get the SkyFrame
  my ($fsout, $outax) = get_frameset_via_template( $fset,
                                                Starlink::AST::SkyFrame->new( "MaxAxes=100" ),
                                              );
  return unless defined $fsout;
  return unless $fsout->HasAttribute( "SkyRefIs" ); # Defensive

  # Make sure we have the right attributes
  $fsout->Set( 'system' => 'ICRS',
               'SkyRefIs' => "ignored",
             );

  # Calculate the GRID coordinates of the 4 SkyFrame corners
  my $xcoords = $outax->[0] - 1;
  my $ycoords = $outax->[1] - 1;
  my (@gx_in, @gy_in);
  $gx_in[0] = $gx_in[2] = $ubnd->[$xcoords] - $lbnd->[$xcoords] + 1;   # Right
  $gx_in[1] = $gx_in[3] = 1.0; # Left
  $gy_in[0] = $gy_in[1] = $ubnd->[$ycoords] - $lbnd->[$ycoords] + 1;   # Top
  $gy_in[2] = $gy_in[3] = 1.0; # Bottom

  # The centre
  $gx_in[4] = ($gx_in[0] + $gx_in[1]) / 2.0;
  $gy_in[4] = ($gy_in[0] + $gy_in[2]) / 2.0;

  my ($gx_out, $gy_out) = $fsout->Tran2( \@gx_in, \@gy_in, 1 );

  # Work out whether X or Y is the longitude
  my $lonaxis = $fsout->Get("LonAxis");
  my $lataxis = $fsout->Get("LatAxis");

  my $xname = "ra";
  my $yname = "dec";
  if ($lonaxis == 2) {
    $xname = "dec";
    $yname = "ra";
  }

  # TR, TL, BR, BL
  my %results;
  for my $corner (qw/ top_right top_left bottom_right bottom_left centre /) {
    my $xval = shift(@$gx_out);
    my $yval = shift(@$gy_out);

    # Check for bad values
    if ($xval > -1e100 && $yval > -1e100) {
      $results{$corner} = Astro::Coords->new( $xname => $xval,
                                              $yname => $yval,
                                              type => "J2000",
                                              units => 'radians' );
    } else {
      $results{$corner} = undef;
    }

  }

  # Retrieve the sky reference
  my $refra = $fsout->Get( "SkyRef($lonaxis)");
  my $refdec = $fsout->Get( "SkyRef($lataxis)");
  $results{reference} = Astro::Coords->new( ra => $refra,
                                            dec => $refdec,
                                            type => "J2000",
                                            units => 'radians');

  return %results;
}


=item B<get_frameset_via_template>

Given a frameset and a template, return a frameset
that contains only the mappings and coordinates
relevant to the template.

  ($newfs, $outax) = get_frameset_via_template( $infs, $template );

where the template is a frame of any class and the
returned outax is a reference to an array containing
the indices into the original frameset base GRID frame
relevant mapped to the new frameset (1-based).

Returns empty list if a template does not match or if the
mapping can not be split.

=cut

sub get_frameset_via_template {
  my $fset = shift;
  my $template = shift;

 # Copy the frame set
  $fset = $fset->Copy();

  # Set the base frame to GRID
  my $nframes = $fset->GetI( "NFrame" );
  my $bfrm;
  for my $i (1..$nframes) {
    my $tfrm = $fset->GetFrame( $i );
    my $domain = $tfrm->GetC( "Domain" );
    if ($domain && $domain eq 'GRID') {
      $fset->SetI( "Base", $i );
      $bfrm = $tfrm;
      last;
    }
  }

  # do not continue if no GRID frame
  return () unless defined $bfrm;

  # Find the matching frame
  my $matchfset = $fset->FindFrame( $template, "" );

  return () unless defined $matchfset;

  # Get the mapping from template to the base frame
  my $map = $matchfset->GetMapping( Starlink::AST::AST__CURRENT(),
                                    Starlink::AST::AST__BASE() );

  # Get the specframe itself
  my $cfrm = $matchfset->GetFrame( Starlink::AST::AST__CURRENT() );

  # May have an N-d frameset so have to split the mapping
  # with the correct number of inputs (note that the mapping goes
  # from the frame that matched the template to the multi-dim GRID)
  my $nin = $map->GetI( "Nin" );
  my @axin = (1..$nin);

  my ($splitmap, @outax) = $map->MapSplit( \@axin );

  if (defined $splitmap && $splitmap->GetI("Nout") == $nin) {
    # Now pick out the corresponding axis from the base frame
    my $gfrm = $bfrm->PickAxes( \@outax );

    # and put it together into a new frameset
    my $fsout = Starlink::AST::FrameSet->new( $gfrm, "" );
    $splitmap->Invert();
    $fsout->AddFrame( Starlink::AST::AST__BASE(), $splitmap, $cfrm );

    return ( $fsout, \@outax );

  }

  return;
}

=back

=end _HELPER_ROUTINES_

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
