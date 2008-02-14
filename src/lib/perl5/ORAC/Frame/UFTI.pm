package ORAC::Frame::UFTI;

=head1 NAME

ORAC::Frame::UFTI - UFTI class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UFTI;

  $Frm = new ORAC::Frame::UFTI("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to UFTI prior to ORAC delivery. It provides a class derived
from B<ORAC::Frame::UKIRT>.  All the methods available to
B<ORAC::Frame::UKIRT> objects are available to B<ORAC::Frame::UFTI>
objects. Some additional methods are supplied.

=cut

# A package to describe a UFTI group object for the
# ORAC pipeline

# standard error module and turn on strict
use Carp;
use strict;
use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame::UKIRT;
use base qw/ORAC::Frame::UKIRT/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for UFTI should go here
my %hdr = (
            EXPOSURE_TIME        => "EXP_TIME",
            DEC_SCALE            => "CDELT2",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            GAIN                 => "GAIN",
            RA_SCALE             => "CDELT1",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
            UTEND                => "UTEND",
            UTSTART              => "UTSTART"
	  );

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.
ORAC::Frame::UFTI->_generate_orac_lookup_methods( \%hdr );

# Allow for missing, undefined, and malformed headers.
sub _to_DEC_BASE {
   my $self = shift;
   my $dec = undef;
   if ( exists $self->hdr->{DECBASE} ) {
      $dec = $self->hdr->{DECBASE};

# Cope with some early data with FITS-header values starting in the
# erroneous column 10, and thus making the FITS parser think it is a
# comment.  These begin with an equals sign.  The value is then the
# first word after the removed equals sign.
      if ( defined( $dec ) && $dec =~ /^=/ ) {
         $dec =~ s/=//;
         my @words = split( /\s+/, $dec );
         $dec = $words[ 0 ];
      }
   }
   return $dec;
}

# Allow for missing, ubdefined, and malformed headers.
sub _to_RA_BASE {
   my $self = shift;
   my $ra = undef;
   if ( exists $self->hdr->{RABASE} ) {
      $ra = $self->hdr->{RABASE};

# Cope with some early data with FITS-header values starting in the
# erroneous column 10, and thus making the FITS parser think it is a
# comment.  These begin with an equals sign.  The value is then the
# first word after the removed equals sign.
      if ( defined( $ra ) && $ra =~ /^=/ ) {
         $ra =~ s/=//;
         my @words = split( /\s+/, $ra );
         $ra = $words[ 0 ];
      }
      $ra *= 15.0;
   }
   return $ra;
}

# Allow for multiple occurences of the date, the first being valid and
# the second is blank.
sub _to_UTDATE {
  my $self = shift;
  my $utdate;
  if ( exists $self->hdr->{DATE} ) {
     $utdate = $self->hdr->{DATE};

# This is a kludge to work with old data which has multiple values of
# the DATE keyword with the last value being blank (these were early
# UFTI data).  Return the first value, since the last value can be
# blank. 
     if ( ref( $utdate ) eq 'ARRAY' ) {
        $utdate = $utdate->[0];
     }
     # remove '-'
     $utdate =~ s/-//g;
  }
  return $utdate;
}

# Specify the reference pixel, which is normally near the frame centre.
# There may be small displacements to avoid detector joins or for
# polarimetry using a Wollaston prism.
sub _to_X_REFERENCE_PIXEL{
  my $self = shift;
  my $xref;

# Use the average of the bounds to define the centre and dimension.
  if ( exists $self->hdr->{RDOUT_X1} && exists $self->hdr->{RDOUT_X2} ) {
    my $xl = $self->hdr->{RDOUT_X1};
    my $xu = $self->hdr->{RDOUT_X2};
    my $xdim = $xu - $xl + 1;
    my $xmid = nint( ( $xl + $xu ) / 2 );

# UFTI is at the centre for a sub-array along an axis but offset slightly
# for a sub-array to avoid the joins between the four sub-array sections
# of the frame.  Ideally these should come through the headers...
    if ( $xdim == 1024 ) {
      $xref = $xmid + 20;
    } else {
      $xref = $xmid;
    }

# Correct for IRPOL beam splitting with a 6" E offset.
    if ( $self->hdr->{FILTER} =~ m/pol/ ) {
      $xref -= 65.5;
    }

# Use a default which assumes the full array (slightly offset from the
# centre).
  } else {
    $xref = 533;
  }
  return $xref;
}

sub _from_X_REFERENCE_PIXEL {
  "CRPIX1", $_[0]->uhdr("ORAC_X_REFERENCE_PIXEL");
}

# Specify the reference pixel, which is normally near the frame centre.
# There may be small displacements to avoid detector joins or for
# polarimetry using a Wollaston prism.
sub _to_Y_REFERENCE_PIXEL{
  my $self = shift;
  my $yref;

# Use the average of the bounds to define the centre and dimension.
  if ( exists $self->hdr->{RDOUT_Y1} && exists $self->hdr->{RDOUT_Y2} ) {
    my $yl = $self->hdr->{RDOUT_Y1};
    my $yu = $self->hdr->{RDOUT_Y2};
    my $ydim = $yu - $yl + 1;
    my $ymid = nint( ( $yl + $yu ) / 2 );

# UFTI is at the centre for a sub-array along an axis but offset slightly
# for a sub-array to avoid the joins between the four sub-array sections
# of the frame.  Ideally these should come through the headers...
    if ( $ydim == 1024 ) {
      $yref = $ymid - 25;
    } else {
      $yref = $ymid;
    }

# Correct for IRPOL beam splitting with a " N offset.
    if ( $self->hdr->{FILTER} =~ m/pol/ ) {
      $yref += 253;
    }

# Use a default which assumes the full array (slightly offset from the
# centre).
  } else {
    $yref = 488;
  }
  return $yref;
}

sub _from_Y_REFERENCE_PIXEL {
  "CRPIX2", $_[0]->uhdr("ORAC_Y_REFERENCE_PIXEL");
}

sub _to_POLARIMETRY {
  my $self = shift;
  if( exists( $self->hdr->{FILTER} ) &&
      $self->hdr->{FILTER} =~ /pol/i ) {
    return 1;
  } else {
    return 0;
  }
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::UKIRT>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::UFTI> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::UFTI;
   $Frm = new ORAC::Frame::UFTI("file_name");
   $Frm = new ORAC::Frame::UFTI("UT","number");

The constructor hard-wires the '.fits' rawsuffix and the
'f' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

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
  $self->rawfixedpart('f');
  $self->rawsuffix('.fits');
  $self->rawformat('FITS');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;

}

=back

=head2 General Methods

=over 4

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

pattern_from_bits() is currently an alias for file_from_bits(),
and both can be used interchangably for the UFTI subclass.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes - 5(!) digit obsnum
  my $padnum = '0'x(5-length($obsnum)) . $obsnum;

  # UFTI naming
  return $self->rawfixedpart . $prefix . '_' . $padnum . $self->rawsuffix;
}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
UFTI.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # It is almost possible to derive the flag name from the 
  # file name but not quite. In the UFTI case the flag name
  # is  .UT_obsnum.fits.ok but the filename is fUT_obsnum.fits

  # Retrieve the data file name
  my $raw = $self->pattern_from_bits($prefix, $obsnum);

  # Replace the 'f' with a '.' and append '.ok'
  substr($raw,0,1) = '.';
  $raw .= '.ok';
}

# Supply a method to return the number associated with the observation

#=item B<number>

# Method to return the number of the observation. This is the
# number stored in the OBSNUM header

#   $number = $Frm->number;


### Note: this has been removed as it caused the -from -skip
### option combination to fail - FE

# =cut


# sub number {

#   my $self = shift;

#   my $number = $self->hdr('OBSNUM');

#   return $number;

# }


=item B<template>

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Frm->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $num = $self->number;
  # pad with leading zeroes - 5(!) digit obsnum
  $num = '0'x(5-length($num)) . $num;

  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($template);

}



=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2008 Science and Technology Facilities Council.
Copyright (C) 1998-2007 Particle Physics and Astronomy Research
Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

 
1;
