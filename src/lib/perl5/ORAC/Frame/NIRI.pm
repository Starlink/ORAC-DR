package ORAC::Frame::NIRI;

=head1 NAME

ORAC::Frame::NIRI - class for dealing with NIRI observation files in ORAC-DR

This module provides methods for handling Frame objects that are
specific to NIRI. It provides a class derived from
B<ORAC::Frame::GEMINI>.

=cut

# A package to describe a NIRI group object for the
# ORAC pipeline

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::NIRI;
use ORAC::Constants;
use ORAC::Print;
use ORAC::General;
use NDF;
use Starlink::HDSPACK qw/copobj/;


# Let the object know that it is derived from ORAC::Frame::GEMINI;
use base qw/ORAC::Frame::GEMINI/;

# standard error module and turn on strict
use Carp;
use strict;

# These header translations may or may not be generic, so place here
# for the moment.
my %hdr = (
            DETECTOR_READ_TYPE   => "MODE",
#            NUMBER_OF_OFFSETS   => "NOFFSETS",
       );
            
# Take this lookup table and generate methods.
ORAC::Frame::NIRI->_generate_orac_lookup_methods( \%hdr );

sub _to_EXPOSURE_TIME {
   my $self = shift;
   my $et = $self->hdr->{EXPTIME};
   my $co = $self->hdr->{COADDS};
   $et *= $co;
}

sub _to_GAIN {
  12.3; # hardwire in gain for now
}

sub _to_OBSERVATION_MODE {
   "imaging";
}

sub _to_OBSERVATION_NUMBER {
   my $self = shift;
   my $obsnum = 0;
   if ( exists ( $self->hdr->{FRMNAME} ) ) {
      my $fname = $self->hdr->{FRMNAME};
      $obsnum = substr( $fname, index( $fname, ":" ) - 4, 4 );
   }
   return $obsnum;
}

# Convert the CD matrix to an average rotation.  Equations here are from 
# FITS-WCS Paper II Section 6.2, 191 and 192.

sub _to_ROTATION {
   my $self = shift;
   my $rotation;
   if ( exists( $self->hdr->{CD1_1} ) ) {
      my $cd11 = $self->hdr("CD1_1");
      my $cd12 = $self->hdr("CD1_2");
      my $cd21 = $self->hdr("CD2_1");
      my $cd22 = $self->hdr("CD2_2");

# Radians to degrees conversion.
      my $rtod = 45 / atan2( 1, 1 );

# Determine the sense of the scales.
      my $sgn_a;
      if ( $cd21 < 0 ) { $sgn_a = -1; } else { $sgn_a = 1; }
      my $sgn_b;
      if ( $cd12 < 0 ) { $sgn_b = -1; } else { $sgn_b = 1; }

# Form first rotation estimate.  Zero off-diagonal term implies zero
# rotation.
      my $nrot = 0;
      my $rho_a = 0;
      if ( abs( $cd21 / $cd11 ) > 1E-6 ) {
         $rho_a = atan2( $sgn_a * $cd21 / $rtod, $sgn_a * $cd11 / $rtod );
         $nrot++
      }

# Form first rotation estimate.  Zero off-diagonal term implies zero
# rotation.
      my $rho_b = 0;
      if ( abs( $cd12 / $cd22 ) > 1E-6 ) {
         $rho_b = atan2( $sgn_b * $cd12 / $rtod, -$sgn_b * $cd22 / $rtod );
         $nrot++
      }

# Average the estimates of the rotation.  This needs a further check
# that the two values are compatible based upon the signs of pairs of the
# four elements.
      if ( $nrot > 0 ) {
         $rotation = $rtod * ( $rho_a + $rho_b ) / $nrot;
      }
   
# The actual WCS matrix has errors and sometimes the angle which
# should be near 180 degrees for the f/32 camera, can be out by 90 
# degrees.  So for this camera we hardwired the main rotation and
# merely apply the small deviation from the cardinal orientations.
      if ( defined( $self->hdr( "INPORT" ) ) && $self->hdr( "INPORT" ) == 3 ) {
         my $delta_rho = 0.0;
         if ( defined( $rotation ) ) {
            $delta_rho = $rotation - ( 90 * int( $rotation / 90 ) );
         }
         $delta_rho -= 90 if ( $delta_rho > 45 );
         $delta_rho += 90 if ( $delta_rho < -45 );

# Setting to 180 is a fudge because the CD matrix appears is wrong
# occasionally by 90 degrees for port 3, the f/32 camera, judging by the
# telescope offsets, CTYPEn, and the support astronomer.  This has not
# been corrected despite MJC's report.
         $rotation = 180.0 + $delta_rho;

# Guess a reasonable default if the CD matrix fails to generate
# a rotation angle.
      } elsif( ! defined( $rotation ) ) {
         $rotation = 0;
      }
   }
   return $rotation;
}

sub _to_SPEED_GAIN {
   "NA";
}

sub _to_STANDARD {
   0; # hardwire for now as all objects not a standard.
}

sub _to_UTSTART {
   my $self = shift;

# Obtain the UT start time and convert to decimal hours.
   my $utstring = $self->hdr( "UT" );
   my $ut = 0.0;
   if ( defined( $utstring ) && $utstring !~ /\s+/ && $utstring !~ /Value/ ) {
      $ut = hmstodec( $utstring );
   }
   return $ut;
}

sub _to_WAVEPLATE_ANGLE {
   0; # hardwire angle for now
}

# Shift the bounds to GRID co-ordinates.
sub _to_X_LOWER_BOUND {
   my $self = shift;
   my $bound = 1;
   if ( exists( $self->hdr->{LOWCOL} ) ) {
      $bound = nint( $self->hdr->{LOWCOL} + 1 );
   }
   return $bound;
}

sub _to_Y_LOWER_BOUND {
   my $self = shift;
   my $bound = 1;
   if ( exists( $self->hdr->{LOWROW} ) ) {
      $bound = nint( $self->hdr->{LOWROW} + 1 );
   }
   return $bound;
}

sub _to_X_UPPER_BOUND {
   my $self = shift;
   my $bound = 1024;
   if ( exists( $self->hdr->{HICOL} ) ) {
      $bound = nint( $self->hdr->{HICOL} + 1 );
   }
   return $bound;
}

sub _to_Y_UPPER_BOUND {
   my $self = shift;
   my $bound = 1024;
   if ( exists( $self->hdr->{HIROW} ) ) {
      $bound = nint( $self->hdr->{HIROW} + 1 );
   }
   return $bound;
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::GEMINI>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::NIRI> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::NIRI;
   $Frm = new ORAC::Frame::NIRI("file_name");
   $Frm = new ORAC::Frame::NIRI("UT","number");

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with 
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('N');
  $self->rawsuffix('.fits');
  $self->rawformat('GMEF');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;

}
=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), findgroup(), findrecipe and findnsubs()
methods are invoked by this command. Arguments are required.  If there
is one argument it is assumed that this is the raw filename. If there
are two arguments the filename is constructed assuming that arg 1 is
the prefix and arg2 is the observation number.

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
    $fname = shift;
  } elsif (scalar(@_) == 2) {
    $fname = $self->file_from_bits(@_);
  } else {
    croak 'Wrong number of arguments to configure: 1 or 2 args only';
  }


  # set the filename

  $self->file($fname);
  my $rootfile = $self->file;

  # Set the raw data file name

  $self->raw($fname);

  # The number of sub frames is difficult. The .HEADER should not be
  # included but in chopped observations we want to use .INBEAMA/B 
  # instead of just .I1. To get around this problem findubs() populates
  # an internal data structure that will contain all the names we are
  # interested in.
  # $self->findnsubs;

  # Read the internal data structure
  # my @Components = @{ $self->{_Components} };

  # Populate the header

  $self->readhdr($self->file);

  # ....and make sure calc_orac_headers is up-to-date after this
  $self->calc_orac_headers;

  # Hack


  # Find the group name and set it
  $self->findgroup;

  # Find the recipe name
  $self->findrecipe;

  # Return something
  return 1;
}

=item B<findnsubs>

This method returns the number of .I? NDFs found in an HDS container.
It can not simply count the number of NDFs and subtract 1 (the .HEADER)
because Michelle stored extra NDFs in the container.

  $ncomp = $Frm->findnsubs;

The header is updated.

Additionally, the names of the components are stored in an internal
data structure so that configure() can access them. This is because
in Michelle the chopped observations should not use .I1 but rather
the chopped frames themselves.

=cut

sub findnsubs {
  my $self = shift;

  my $file = shift;

  my ($loc,$status);

  unless (defined $file) {
    $file = $self->file;
  }

  # Now need to find the NDFs in the output HDS file
  $status = &NDF::SAI__OK;
  hds_open($file, 'READ', $loc, $status);

  # Need to rely on status being good before proceeding
  my @comps;
  if ($status == &NDF::SAI__OK) {

    # Find out how many we have
    dat_ncomp($loc, my $ncomp, $status);

    # Get all the component names
    for my $i (1..$ncomp) {

      # Get locator to component
      dat_index($loc, $i, my $cloc, $status);

      # Find its name
      dat_name($cloc, my $name, $status);
      push(@comps, $name) if $status == &NDF::SAI__OK;

      # Release locator
      dat_annul($cloc, $status);

      last if $status != &NDF::SAI__OK;
    }

  }

  # Close file
  dat_annul($loc, $status);

  unless ($status == &NDF::SAI__OK) {
    orac_err("Can't open $file for nsubs or error reading components\n");
    return 0;
  }

  # Now need to go through component names looking for useful names
  my (@IN, @INBEAM);
  for my $comp (@comps) {
    if ($comp =~ /^I\d+$/) {
      push(@IN, $comp);
    } elsif ($comp =~ /^I\d+BEAM/) {
      push(@INBEAM, $comp);
    }
  }

  # Now see what we have
  my ($ncomp, @result);
  if (@INBEAM) {
    # Chopped observation
    @result = @INBEAM;
  } elsif (@IN) {
    # Standard HDS observation
    @result = @IN;
  }

  $ncomp = scalar(@result);
  $self->{_Components} = [@result];

  unless (defined $ncomp) {
    orac_err "Could not find .I1?? NDF component in file $file\n";
    return 0;
  }

  # Update the header
  $self->nsubs($ncomp);

  return $ncomp;

}

=back

=head2 General Methods

=over 4

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
NIRI.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;


  # It is almost possible to derive the flag name from the 
  # file name but not quite. In the NIRI case the flag name
  # is  .UT_obsnum.fits.ok but the filename is fUT_obsnum.fits

  # Retrieve the data file name
  my $raw = file_from_bits($prefix, $obsnum);

  # Replace prepend  '.', drop the suffix and append '.ok'
  my $suffix = $self->rawsuffix;
  $raw =~ s/$suffix$//;
  my $flag = ".$raw.ok";

}

=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number at the end of the raw data
filename.  For example a number can be extracted from strings of the
form textNNNN.sdf or textNNNN, where NNNN is a number (leading zeroes
are stripped) but not textNNNNtext (number must be followed by a decimal
point or nothing at all).

  $number = $Frm->number;

The return value is -1 if no number can be determined.

As an aside, an alternative approach for this method (especially
in a sub-class) would be to read the number from the header.

=cut

sub number {

  my $self = shift;

  my ($number);

  # Get the number from the raw data filename
  # Leading zeroes are dropped

  my $raw = $self->raw;
  if (defined $raw && $raw =~ /N(\d+)_(\d+)_raw.sdf$/) {
    # Drop leading 00
    $number = $2 * 1;
  } else {
    # No match so set to -1
    $number = -1;
  }

  return $number;

}


=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

$fname = $Frm->file_from_bits($prefix, $obsnum);

=cut

sub file_from_bits { 
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # File numbers are padded to 4  digits.
  $obsnum = sprintf("%04d", $obsnum);

  return $self->rawfixedpart . $prefix . 'S' . $obsnum . $self->rawsuffix;

}

=back


=item B<template>

Create new file name from template. zero-pads.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $num = $self->number;
  # pad with leading zeroes - 4-digit obsnum
  $num = '0'x(4-length($num)) . $num;

  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($template);

}

=item B<findrecipe>

I subclass this so that I don't have to have the no recipe warning each time...

Method to determine the recipe name that should be used to reduce the
observation.  The default method is to look for an "ORAC_RECIPE" entry
in the user header. If one cannot be found, we assume QUICK_LOOK.

  $recipe = $Frm->findrecipe;

The object is automatically updated to reflect this recipe.

=cut


sub findrecipe {
  my $self = shift;

  my $recipe = $self->uhdr('ORAC_RECIPE');

  # Check to see whether there is something there
  # if not try to make something up

  if (!defined($recipe) or $recipe !~ /./) {
    $recipe = 'QUICK_LOOK';
  }

  # Update
  $self->recipe($recipe);

  return $recipe;
}
=item B<mergehdr>

Method to propagate the FITS header from an HDS container to an NDF
Run after updating $Frm.

 $Frm->files($out);
 $Frm->mergehdr;

=cut

sub mergehdr {

  my $self = shift;
  my $status;

  my $old = pop(@{$self->intermediates});
  my $new = $self->file;

  my ($root, $rest) = $self->_split_name($old);

  if (defined $rest) {
    $status = &NDF::SAI__OK;

    # determine whether we have got a .MORE component already
    ndf_begin();
    ndf_find(&NDF::DAT__ROOT(), $new, my $indf, $status);
    ndf_xnumb($indf, my $num, $status);
    ndf_annul($indf, $status);
    ndf_end($status);

    # if we have no extensions we have to copy the whole .MORE
    # if we have some extensions just copy .FITS
    my $copy = ( $num ? "MORE.FITS" : "MORE");

    $status = copobj($root.".header.$copy",$new.".$copy",$status);

    orac_err("Failed dismally to propagate HDS header from $root to NDF file $new\n") unless ($status==&NDF::SAI__OK);

  };

}


=item B<_split_name>

Internal routine to split a 'file' name into an actual
filename (the HDS container) and the NDF name (the
thing inside the container).

Splits on '.'

Argument: string to split (eg test.i1)
Returns:  root name, ndf name (eg 'test' and 'i1')

NDF name is undef if there are no 'sub-frames'.

This routine is so simple that it may not be worth the effort.

=cut

sub _split_name {
  my $self = shift;
  my $file  = shift;

  # Split on '.'
  my ($root, $rest) = split(/\./, $file, 2);

  return ($root, $rest);
}


=head1 SEE ALSO

L<ORAC::Group>

=head1 AUTHORS

Paul Hirst <p.hirst@jach.hawaii.edu>
Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
