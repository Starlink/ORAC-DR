package ORAC::Frame::JCMT;

=head1 NAME

ORAC::Frame::JCMT - JCMT class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::JCMT;

  $Frm = new ORAC::Frame::JCMT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to JCMT. It provides a class derived from B<ORAC::Frame>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::JCMT> objects. Some additional methods are supplied.

=cut

# A package to describe a JCMT frame object for the
# ORAC pipeline

use 5.006;
use warnings;
use ORAC::Frame::NDF;
use ORAC::Constants;
use ORAC::Print;

use vars qw/$VERSION/;

# Let the object know that it is derived from ORAC::Frame;
@ORAC::Frame::JCMT::ISA = qw/ORAC::Frame::NDF/;

# Use base doesn't seem to work...
#use base qw/ ORAC::Frame /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

# standard error module and turn on strict
use Carp;
use strict;

=head1 PUBLIC METHODS

The following are modifications to standard ORAC::Frame methods.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::JCMT> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::JCMT;
   $Frm = new ORAC::Frame::JCMT("file_name");
   $Frm = new ORAC::Frame::JCMT("UT","number");

This method runs the base class constructor and then modifies
the rawsuffix and rawfixedpart to be '.sdf' and '_dem_'
respectively.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new({
				 Subs => [],
				 Filters => [],
				 WaveLengths => [],
				});

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('_dem_');
  $self->rawsuffix('.sdf');
  $self->rawformat('NDF');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;
}

=back

=head2 Subclassed methods

The following methods are provided for manipulating
B<ORAC::Frame::JCMT> objects. These methods override those
provided by B<ORAC::Frame>.

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

ORACTIME is calculated - this is the time of the observation as
UT day + fraction of day.

ORACUT is simply read from UTDATE converted to YYYYMMDD.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  my %new = ();  # Hash containing the derived headers

  # ORACTIME

  # First get the time of day
  my $time = $self->hdr('UTSTART');
  if (defined $time) {
    # Need to split on :
    my ($h,$m,$s) = split(/:/,$time);

    # some times, we get a dodgy seconds value
    # See eg 19970921_dem_0025.sdf
    if ($s > 61) {
      # get it from the HSTSTART
      my $hst = $self->hdr('HSTSTART');
      if (defined $hst) {
	my ($hh, $hm, $hs) = split(/:/, $hst);
	$s = $hs;
      } else {
	# panic. Take the first 2 digits
	$s = substr($s,0,2);
      }
    }
    $time = $h + $m/60 + $s/3600;
  } else {
    $time = 0;
  }

  # Now get the UT date
  my $date = $self->hdr('UTDATE');
  if (defined $date) {
    my ($y,$m,$d) = split(/:/, $date);
    $date = $y . '0'x (2-length($m)) . $m . '0'x (2-length($d)) . $d;
  } else {
    $date = 0;
  }

  my $ut = $date + ( $time / 24.0 );

  # WVM data from header if it is there
  my ($wvm, $wvmstdev);
  eval {
    require SCUBA::WVM;
    my $file = $self->file;
    $file .= ".sdf" unless $file =~ /sdf$/; # bizarrely
   ($wvm, $wvmstdev) = SCUBA::WVM::wvmtau( $file );
  };

  # Update the header
  $self->uhdr( 'ORAC_WVM_TAU', $wvm );
  $self->uhdr( 'ORAC_WVM_TAU_STDEV', $wvmstdev );
  $self->hdr('ORACTIME', $ut);
  $self->hdr('ORACUT',   $date);

  $new{'ORACTIME'} = $ut;
  return %new;

}

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), findgroup(), findrecipe(), findsubs() 
findfilters() and findwavelengths() methods are
invoked by this command. Arguments are required.
If there is one argument it is assumed that this is the
raw filename. If there are two arguments the filename is
constructed assuming that arg 1 is the prefix and arg2 is the
observation number.

  $Frm->configure("fname");
  $Frm->configure("UT","num");

The sub-instrument configuration is also stored.

=cut

sub configure {
  my $self = shift;

  # Run base class configure
  $self->SUPER::configure(@_);

  # Find number of sub-instruments from header
  # Nsubs is already run in the base class.
  # and store this value along with all sub-instrument info.
  # Do this so that the header can be changed without us
  # losing the original state information

  $self->findsubs;
  $self->findfilters;
  $self->findwavelengths;

  # Return something
  return 1;
}


=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

pattern_from_bits() is currently an alias for file_from_bits(),
and both can be used interchangably for SCUBA.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes
  my $padnum = '0'x(4-length($obsnum)) . $obsnum;

  # SCUBA naming
  return $prefix . $self->rawfixedpart . $padnum . $self->rawsuffix;
}

=item B<flag_from_bits>

Determine the flag filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

The format is ".20021001_dem_0001"

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes
  my $padnum = '0'x(4-length($obsnum)) . $obsnum;

  # SCUBA naming
  return "." . $prefix . $self->rawfixedpart . $padnum;
}

=item B<findgroup>

Return the group associated with the Frame. This group is constructed
from header information. The group name is automatically updated in
the object via the group() method.

The group membership can be set using the DRGROUP keyword in the
header. If this keyword exists and is not equal to 'UNKNOWN' the
contents will be returned.

Alternatively, if DRGROUP is not specified the group name is
constructed from the MODE, OBJECT and FILTER keywords. This may cause
problems in the following cases:

 - The chop throw changes and the data should not be coadded
 [in general this is true except for LO chopping scan maps
 where all 6 chops should be included in the group]

 - The source name is the same, the mode is the same and the
 filter is the same but the source coordinates are different by
 a degree or more. In some cases [a large scan map] these should
 be in the same group. In other cases they probably should not
 be. Should I worry about it? One example was where the observer
 used RB coordinates by mistake for a first map and then changed
 to RJ -- the coordinates and source name were identical but the
 position on the sky was miles off. Maybe this should be dealt with
 by using the Frame ON/OFF facility [so it would be part of the group
 but the observer would turn the observation off]

 - Different source names are being used for offsets around
 a common centre [eg the Galactic Centre scan maps]. In this case
 we do want to coadd but this means we should be using position
 rather than source name. Also, how do we define when two fields
 are too far apart to be coadded

 - Photometry data should never be in the same group as a source
 that has a different pointing centre. Note this really should take
 MAP_X and MAP_Y into account since data should be of the same group
 if either the ra/dec is given or if the mapx/y is given relative
 to a fixed ra/dec.

Bottom line is the following (I think).

In all cases the actual position in RJ coordinates should be calculated
(taking into account RB-E<gt>RJ and GA-E<gt>RJ and map_x map_y, local_coords) 
using Astro::SLA. Filter should also be matched as now.
Planets will be special cases - matching on name rather than position.

PHOTOM observations

  Should match positions exactly (within 1 arcsec). Should also match
  chop throws [since the gain is different]. The observer is responsible
  for a final coadd. Source name then becomes irrelevant.

JIGGLE MAP

  Should match positions to within 10 arcmin (say). Should match chop
  throw.

SCAN MAP

  Should match positions to 1 or 2 degrees?
  Should ignore chop throws (the primitive deals with that).

The group name will then use the position with a number of significant
figures changing depending on the position tolerance.


=cut

# Supply a new method for finding a group

sub findgroup {

  my $self = shift;
  my $group;

  if (exists $self->hdr->{DRGROUP} && $self->hdr->{DRGROUP} ne 'UNKNOWN'
      && $self->hdr->{DRGROUP} =~ /\w/) {
    $group = $self->hdr->{DRGROUP};
  } else {
    # construct group name
    $group = $self->hdr('MODE') .
      $self->hdr('OBJECT').
	$self->hdr('FILTER');

    # If we are doing an EMII scan map we need to make sure
    # the group is different from a normal map
    if ($self->hdr('SAM_MODE') eq 'RASTER' && $self->hdr('CHOP_CRD') eq 'LO') {
      $group .= 'emII';
    }
  }

  # Update $group
  $self->group($group);

  return $group;
}


=item B<findnsubs>

Forces the object to determine the number of sub-instruments
associated with the data by looking in the header (hdr()). 
The result is stored in the object using nsubs().

Unlike findgroup() this method will always search the header for
the current state.

=cut

sub findnsubs {
  my $self = shift;
  
  my $nsubs = $self->hdr->{N_SUBS};
  $self->nsubs($nsubs);
  return $nsubs;
}



=item B<findrecipe>

Return the recipe associated with the frame.
The state of the object is automatically updated via the
recipe() method.

The recipe is determined by looking in the FITS header
of the frame. If the 'DRRECIPE' is present and not
set to 'UNKNOWN' then that is assumed to specify the recipe
directly. Otherwise, header information is used to try
to guess at the reduction recipe. The default recipes
are keyed by observing mode:

 SKYDIP => 'SCUBA_SKYDIP'
 NOISE  => 'SCUBA_NOISE'
 POINTING => 'SCUBA_POINTING'
 PHOTOM => 'SCUBA_STD_PHOTOM'
 JIGMAP => 'SCUBA_JIGMAP'
 JIGMAP (phot) => 'SCUBA_JIGPHOTMAP'
 EM2_SCAN => 'SCUBA_EM2SCAN'
 EKH_SCAN => 'SCUBA_EKHSCAN'
 JIGPOLMAP => 'SCUBA_JIGPOLMAP'
 SCANPOLMAP => 'SCUBA_SCANPOLMAP'
 ALIGN  => 'SCUBA_ALIGN'
 FOCUS  => 'SCUBA_FOCUS'

So called "wide" photometry is treated as a map (although this
depends on the name of the jiggle pattern which may change).

In future we may want to have a separate text file containing
the mapping between observing mode and recipe so that
we dont have to hard wire the relationship.

=cut

sub findrecipe {
  my $self = shift;

  my $recipe = undef;
  my $mode = $self->hdr('MODE');

  # Check for DRRECIPE. Have to make sure it contains something (anything)
  # other thant UNKNOWN.
  if (exists $self->hdr->{DRRECIPE} && $self->hdr->{DRRECIPE} ne 'UNKNOWN'
      && $self->hdr->{DRRECIPE} =~ /\w/) {
    $recipe = $self->hdr->{DRRECIPE};
  } elsif ($mode eq 'SKYDIP') {
    $recipe = 'SCUBA_SKYDIP';
  } elsif ($mode eq 'NOISE') {
    $recipe = 'SCUBA_NOISE';
  } elsif ($mode eq 'POINTING') {
    $recipe = 'SCUBA_POINTING';
  } elsif ($mode eq 'PHOTOM') {
    # Special-case wide photometry. This test relies on the jiggle pattern
    # name
    if ($self->hdr->{JIGL_NAM} =~ /wide/) {
      $recipe = 'SCUBA_JIGMAP';
    } else {
      $recipe = 'SCUBA_STD_PHOTOM';
    }
  } elsif ($mode eq 'ALIGN') {
    $recipe = 'SCUBA_ALIGN';
  } elsif ($mode eq 'FOCUS') {
    $recipe = 'SCUBA_FOCUS';
  } elsif ($mode eq 'POLMAP' || $mode eq 'POLPHOT') {
     if ($self->hdr('SAM_MODE') eq 'JIGGLE') {
       $recipe = 'SCUBA_JIGPOLMAP';
     } else {
       # Scanning polarimetry
       $recipe = 'SCUBA_SCANPOLMAP';
     }

  } elsif ($mode eq 'MAP') {
    if ($self->hdr('SAM_MODE') eq 'JIGGLE') {

      # Check for jiggle maps with phot pixels
      if ($self->hdr('SUB_1') =~ /P2000|P1350|P1100/) {
	$recipe = 'SCUBA_JIGPHOTMAP';
      } else {
	$recipe = 'SCUBA_JIGMAP';	
      }

      # old style Polarimetry
      if ($self->hdr('OBJ_TYPE') =~ /^POL/i) {
	$recipe = 'SCUBA_JIGPOLMAP';
      }

    } else {
      if ($self->hdr('CHOP_CRD') eq 'LO') {
	$recipe = 'SCUBA_EM2SCAN';
      } else {
	$recipe = 'SCUBA_EKHSCAN';
      }
    }
  }

  # Update the recipe
  $self->recipe($recipe);

  return $recipe;
}

=item B<template>

This method is identical to the base class template method
except that only files matching the specified sub-instrument
are affected.

  $Frm->template($template, $sub);

If no sub-instrument is specified then the first file name
is modified

Note that this is different to the base class which accepts
a file number as the second argument. This may need some
rationalisation.

=cut

sub template {
  my $self = shift;

  my $template = shift;

  my $sub = undef;
  if (@_) { $sub = shift; }

  # Now get a list of all the subs
  my @subs = $self->subs;

  # If sub has not been specified then we only process one file
  my $nfiles;
  if (defined $sub) {
    $nfiles = $self->nfiles;
  } else {
    $nfiles =1;
  }

  # Get the observation number
  my $num = $self->number;

  # loop through each file
  # (assumes that we actually have the same number of files as subs
  # Not the case before EXTINCTION  

  for (my $i = 0; $i < $nfiles; $i++) {

    # Do nothing if sub is defined but not equal to the current
    if (defined $sub) { next unless $sub eq $subs[$i]; }

    # Okay we get to here if the subs match or if sub was not
    # defined
    # Now repeat the code in the base class
    # Could we use SUPER::template here? No - since the base
    # class does not understand numbers passed to file

    # Change the first number
    # Wont work if 0004 replaced by 45

    # This pattern depends on knowing the form of the 
    # string being generated by the pipeline. For the SCUBA
    # case _PRE_PROCESS_ sets the root filename to be used by
    # all subsequent primitives. Originally this set the result
    # to o### so that files matched o##_blah
    # Now _PRE_PROCESS_ sets to UT_00##_blah
    # To be truly robust I need to know the number of the file
    # that is being used as a template. For now assume this
    # matches _nnnn_ where the number is zero padded

    $num = ( "0" x (4-length($num))) . $num;

    $template =~ s/_\d+_/_${num}_/;

    # Update the filename
    $self->file($i+1, $template);

  }

}


=back

=head1 NEW METHODS FOR JCMT

This section describes methods that are available in addition
to the standard methods found in B<ORAC::Frame>.

=head2 Accessor Methods

The following extra accessor methods are provided:

=over 4

=item B<filters>

Return or set the filter names associated with each sub-instrument
in the frame.

=cut

sub filters {
  my $self = shift;

  if (@_) {
    @{$self->{Filters}} = @_;
  }

  return @{$self->{Filters}};

}

=item B<subs>

Return or set the names of the sub-instruments associated
with the frame.

=cut

sub subs {
  my $self = shift;

  if (@_) {
    @{$self->{Subs}} = @_;
  }

  return @{$self->{Subs}};

}


=item B<wavelengths>

Return or set the wavelengths associated with each  sub-instrument
in the frame.

=cut

sub wavelengths {
  my $self = shift;

  if (@_) {
    @{$self->{WaveLengths}} = @_;
  }

  return @{$self->{WaveLengths}};

}


=back

=head2 New methods

The following additional methods are provided:

=over 4

=item B<file2sub>

Given a file index, (see file()) returns the associated
sub-instrument.

  $sub = $Frm->file2sub(2)

Returns the first sub name if index is too large.
This assumes that the file names associated wth the
object are linked to sub-instruments (as returned
by the subs method). It is up to the primitive writer
to make sure that subs() tracks changes to files().

=cut

sub file2sub {
  my $self = shift;
  my $index = shift;

  # Look through subs()
  my @subs = $self->subs;

  # Decrement $index so that it matches an array lookup
  $index--;

  if ($index > $#subs) {
    return $subs[0];
  } else {
    return $subs[$index];
  }
}

=item B<findfilters>

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the hdr().

The result is stored in the object using filters(). The sub-inst filter
name is made to match the filter name such that a filter of '450w:850w'
has filter names of '450W' and '850W' despite the entries in the header
being simply '450' and '850'. Photometry filter names are not modified.

Unlike findgroup() this method will always search the header for
the current state.

=cut


sub findfilters {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  # Get the FILTER name
  my $filtname = uc($self->hdr('FILTER'));
  my ($part1, $part2) = split(/:/,$filtname, 2);

  my @filter = ();
  for my $i (1..$nsubs) {

    # Retrieve the filter name from the header
    my $filter = $self->hdr('FILT_'.$i);

    # Loop around searching for the filter part that
    # contains the FILT_N substring
    # If not found, simply insert the FILT_N name itself
    # ( that covers 850S:PHOT )
    my $found = 0;
    for my $part ($part1, $part2) {
      if ($part =~ /$filter/) { # grep is overkill
	push(@filter, $part);
	$found = 1;
	last;
      }
    }

    # Could not find it so store the actual filter name
    push(@filter, $filter) unless $found;
  }

  $self->filters(@filter);
  # print "FILTERS: ",join(", ",@filter),"\n";
  return @filter;
}


=item B<findsubs>

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the header (hdr()). 
The result is stored in the object using subs().

Unlike findgroup() this method will always search the header for
the current state.

=cut

sub findsubs {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  my @subs = ();
  for my $i (1..$nsubs) {
    my $key = 'SUB_' . $i;

    push(@subs, $self->hdr($key));
  }

  # Should now set the value in the object!
  $self->subs(@subs);

  return @subs;
}




=item B<findwavelengths>

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the header (hdr()). 
The result is stored in the object using wavelengths().

Unlike findgroup() this method will always search the header for
the current state.

=cut


sub findwavelengths {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  my @wave = ();
  for my $i (1..$nsubs) {
    my $key = 'WAVE_' . $i;

    push(@wave, $self->hdr($key));
  }

  $self->wavelengths(@wave);

  return @wave;
}


=item B<sub2file>

Given a sub instrument name returns the associated file
index. This is the reverse of sub2file. The resulting value
can be used directly in file() to retrieve the file name.

  $file = $Frm->file($Frm->sub2file('LONG'));

A case insensitive comparison is performed.

Returns 1 if nothing matched (ie just returns the first file
in file(). This is probably a bug.

Assumes that changes in subs() are reflected in files().

=cut

sub sub2file {
  my $self = shift;
  my $sub = lc(shift);

  # The index can be found by going thourgh @subs until
  # we find a match
  my @subs = $self->subs;

  my $index = 1; # return first file name at least
  for my $i (0..$#subs) {
    if ($sub eq lc($subs[$i])) {
      $index = $i + 1;
      last;
    }
  }

  return $index;
}


=back

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
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
