package ORAC::Frame::JCMT;

=head1 NAME

ORAC::Frame::JCMT - JCMT class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::JCMT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to JCMT. It provides a class derived from ORAC::Frame.
All the methods available to ORAC::Frame objects are available
to ORAC::Frame::JCMT objects. Some additional methods are supplied.

=cut

# A package to describe a JCMT frame object for the
# ORAC pipeline

use 5.004;
use ORAC::Frame;
use ORAC::Constants;

# Let the object know that it is derived from ORAC::Frame;
@ORAC::Frame::JCMT::ISA = qw/ORAC::Frame/;

# Use base doesn't seem to work...
#use base qw/ ORAC::Frame /;


# standard error module and turn on strict
use Carp;
use strict;

use NDF; # For fits reading

=head1 METHODS

Modifications to standard ORAC::Frame methods.

=over 4

=item new

Create a new instance of a ORAC::Frame::JCMT object.
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


This object has additional support for multiple sub-instruments.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $frame = {};  # Anon hash
 
  $frame->{RawName} = undef;
  $frame->{Header} = undef;
  $frame->{Group} = undef;
  $frame->{Files} = [];
  $frame->{NoKeepArr} = [];
  $frame->{Recipe} = undef;
  $frame->{Nsubs} = undef;
  $frame->{Subs} = [];
  $frame->{Filters} = [];
  $frame->{WaveLengths} = [];
  $frame->{RawSuffix} = ".sdf";
  $frame->{RawFixedPart} = '_dem_'; 
  $frame->{UserHeader} = {};
  $frame->{Intermediates} = [];

  bless($frame, $class);
 
  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  # This could be extended to include a reference to a hash holding the
  # header info but this may well compromise the object since
  # the best way to generate the header (including extensions) is to use the
  # readhdr method.
 
  if (@_) { 
    $frame->configure(@_);
  }
 
  return $frame;
  
}


=item erase

Erase the current file from disk.

  $Frm->erase($i);

The optional argument specified the file number to be erased.
The argument is identical to that given to the file() method.
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

Note that the file() method is not modified to reflect the
fact the the file associated with it has been removed from disk.

This method is usually called automatically when the file()
method is used to update the current filename and the nokeep()
flag is set to true. In this way, temporary files can be removed
without explicit use of the erase() method. (Just need to
use the nokeep() method after the file() method has been used
to update the current filename).

=cut

sub erase {
  my $self = shift;

  # Retrieve the necessary frame name
  my $file = $self->file(@_);

  # Append the .sdf if required
  $file .= '.sdf' unless $file =~ /\.sdf$/;
 
  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;

}

=item configure

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), header(), group() and recipe() methods are
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

  $self->subs($self->findsubs);
  $self->filters($self->findfilters);
  $self->wavelengths($self->findwavelengths);

  # Return something
  return 1;
}


=item file_from_bits

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

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


=item readhdr

Reads the header from the observation file (the filename is stored
in the object). The reference to the header hash is returned.
This method does not set the header in the object (in general that
is done by configure() ).

    $hashref = $Obj->readhdr;

If there is an error during the read a reference to an empty hash is 
returned.

Currently this method assumes that the reduced group is stored in
NDF format. Only the FITS header is retrieved from the NDF.

There are no input arguments.

=cut

sub readhdr {
 
  my $self = shift;
  
  # Just read the NDF fits header
  my ($ref, $status) = fits_read_header($self->file);
 
  # Return an empty hash if bad status
  $ref = {} if ($status != &NDF::SAI__OK);
 
  return $ref;
}


=item findgroup

Return the group associated with the Frame. 
This group is constructed from header information.

Currently the group name is constructed from the 
MODE, OBJECT and FILTER keywords. This may cause problems
in the following cases:

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
(taking into account RB->RJ and GA->RJ and map_x map_y, local_coords) 
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

  # construct group name
  my $group = $self->hdr('MODE') . 
    $self->hdr('OBJECT'). 
      $self->hdr('FILTER');
 
  # If we are doing an EMII scan map we need to make sure
  # the group is different from a normal map
  if ($self->hdr('SAM_MODE') eq 'RASTER' && $self->hdr('CHOP_CRD') eq 'LO') {
    $group .= 'emII';
  } 


  return $group;

}

=item findrecipe

Return the recipe associated with the frame.
Currently returns undef for all frames except 
skydips. This is because it is not yet decided
how the command line override facility (provided
in the pipeline manager) will know what it can override
and what it can leave alone.

In future we may want to have a separate text file containing
the mapping between observing mode and recipe so that
we dont have to hard wire the relationship.

=cut

sub findrecipe {
  my $self = shift;

  my $recipe = undef;

  if ($self->hdr('MODE') eq 'SKYDIP') {
    $recipe = 'SCUBA_SKYDIP';
  } elsif ($self->hdr('MODE') eq 'NOISE') {
    $recipe = 'SCUBA_NOISE';
  } elsif ($self->hdr('MODE') eq 'POINTING') {
    $recipe = 'SCUBA_POINTING';
  } elsif ($self->hdr('MODE') eq 'PHOTOM') {
    $recipe = 'SCUBA_STD_PHOTOM';
  } elsif ($self->hdr('MODE') eq 'ALIGN') {
    $recipe = 'SCUBA_ALIGN';
  } elsif ($self->hdr('MODE') eq 'FOCUS') {
    $recipe = 'SCUBA_FOCUS';
  } elsif ($self->hdr('MODE') eq 'MAP') {
    if ($self->hdr('SAM_MODE') eq 'JIGGLE') {
      $recipe = 'SCUBA_JIGMAP';

      if ($self->hdr('OBJ_TYPE') eq 'POLARIMETER') {
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

  return $recipe;
}



=item inout

Method to return the current input filename and the 
new output filename given a suffix and a sub-instrument
number.

Returns $in and $out in an array context:

  ($in, $out) = $Frm->inout($suffix, $num);

Returns $out in a scalar context:

  $out = $Frm->inout($suffix, $num);

The second argument indicates the sub-instrument number
and is optional (defaults to first sub-instrument).
If only one file is present then that is used as $infile.
(handled by the file() method.)

Currently, the output filename is constructed by removing
everything after the last underscore and appending the suffix.
If no underscore is found the suffix is appended without chopping.
If the string after the last underscore is simply a number,
it is not removed.

Some examples (suffix = '_trn'):

If input equals "o65" the output filename will be "o65_trn".
If input equals "o65_flat" the output filename will be "o65_trn".
If input equals "19980123_dem_0065" the output filename will be
"19980123_dem_0065_trn".

=cut

sub inout {
  my $num;

  my $self = shift;

  my $suffix = shift;

  # Find the sub-instrument number
  if (@_) { 
    $num = shift;
  } else {
    $num = 1;
  }

  # Read the current file name
  my $infile = $self->file($num);

  # Split on underscore
  my @junk = split(/_/, $infile);

  # Now construct the root for outfile
  # Keep the original root if we have only 1 component
  # or the last component is a number.
  # Else throw away the last one
  
  my $outfile;
  if ($#junk == 0 || $junk[-1] =~ /^\d+$/) {
    $outfile = $infile;
  } else {
    # Recombine array all except last entry
    $outfile = join("_",@junk[0..$#junk-1]);  
  }
  
  $outfile .= $suffix;

  # Generate a warning if output file equals input file
  orac_warn("inout - output filename equals input filename ($outfile)")
    if ($outfile eq $infile);

  return ($infile, $outfile) if wantarray;
  return $outfile;      
}


=item template

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


=item calc_orac_headers

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
  
  # Update the header
  $self->hdr('ORACTIME', $ut);
  $self->hdr('ORACUT',   $date);
 
  $new{'ORACTIME'} = $ut;
  return %new;

}


=item findnsubs

Forces the object to determine the number of sub-instruments
associated with the data by looking in the header(). 
The result can be stored in the object using nsubs().

Unlike findgroup() this method will always search the header for
the current state.

=cut

sub findnsubs {
  my $self = shift;

  return $self->hdr('N_SUBS');
}



=back

=head1 NEW METHODS FOR JCMT

This section describes methods that are available in addition
to the standard methods found in ORAC::Frame.

=over 4

=item file2sub

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

=item sub2file

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
  for (my $i = 0; $i <= $#subs; $i++) {
    if ($sub eq lc($subs[$i])) {
      $index = $i + 1;
      last;
    }
  }
  
  return $index;
}

=item subs

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

=item filters

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

=item wavelengths

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


=item findsubs

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the header(). 
The result can be stored in the object using subs().

Unlike findgroup() this method will always search the header for
the current state.

=cut

sub findsubs {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  my @subs = ();
  for (my $i =1; $i <= $nsubs; $i++) {
    my $key = 'SUB_' . $i;

    push(@subs, $self->hdr($key));
  }

  # Should now set the value in the object!

  return @subs;
}



=item findfilters

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the header(). 
The result can be stored in the object using subs().

Unlike findgroup() this method will always search the header for
the current state.

=cut


sub findfilters {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  my @filter = ();
  for (my $i =1; $i <= $nsubs; $i++) {
    my $key = 'FILT_' . $i;

    push(@filter, $self->hdr($key));
  }

  return @filter;
}


=item findwavelengths

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the header(). 
The result can be stored in the object using subs().

Unlike findgroup() this method will always search the header for
the current state.

=cut


sub findwavelengths {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  my @filter = ();
  for (my $i =1; $i <= $nsubs; $i++) {
    my $key = 'WAVE_' . $i;

    push(@filter, $self->hdr($key));
  }

  return @filter;
}


=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=over 4

=item stripfname

Method to strip file extensions from the filename string. This method
is called by the file() method. For UKIRT we strip all extensions of the
form ".sdf", ".sdf.gz" and ".sdf.Z" since Starlink tasks do not require
the extension when accessing the file name.

=cut

sub stripfname {
 
  my $self = shift;
 
  my $name = shift;
 
  # Strip everything after the first dot
  $name =~ s/\.(sdf)(\.gz|\.Z)?$//;
  
  return $name;
}
 

=back

=head1 REQUIREMENTS

This module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Frame>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=cut




1;
