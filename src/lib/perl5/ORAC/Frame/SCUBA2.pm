package ORAC::Frame::SCUBA2;

=head1 NAME

ORAC::Frame::SCUBA2 - SCUBA-2 class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::SCUBA2;

  $Frm = new ORAC::Frame::SCUBA2("filename");
  $Frm = new ORAC::Frame::SCUBA2(@files);
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to SCUBA-2. It provides a class derived from B<ORAC::Frame>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::SCUBA2> objects. Some additional methods are supplied.

=cut

# A package to describe a JCMT frame object for the
# ORAC pipeline

use 5.006;
use warnings;
use ORAC::Frame::NDF;
use ORAC::Constants;
use ORAC::Print;

use NDF;
use Starlink::HDSPACK qw/ retrieve_locs copobj /;

use vars qw/$VERSION/;

# Let the object know that it is derived from ORAC::Frame;
use base qw/ ORAC::Frame::NDF /;

# Use base doesn't seem to work...
#use base qw/ ORAC::Frame /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# standard error module and turn on strict
use Carp;
use strict;

=head1 PUBLIC METHODS

The following are modifications to standard ORAC::Frame methods.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::SCUBA2> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::SCUBA2;
   $Frm = new ORAC::Frame::SCUBA2("file_name");
   $Frm = new ORAC::Frame::SCUBA2("UT","number");

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
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('s' . $self->_wavelength_prefix );
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
B<ORAC::Frame::SCUBA2> objects. These methods override those
provided by B<ORAC::Frame>.

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

=cut

sub calc_orac_headers {
  my $self = shift;

  my %new = ();  # Hash containing the derived headers

  return %new;

}

=item B<configure>


=cut

sub configure {
  my $self = shift;

  my @fnames;
  if( scalar( @_ ) == 1 ) {
    my $fnamesref = shift;
    @fnames = @$fnamesref;
  } elsif( scalar( @_ ) == 2 ) {

    # SCUBA-2 configure() cannot take 2 arguments.
    croak "configure() for SCUBA-2 cannot take two arguments";

  } else {
    croak "Wrong number of arguments to configure: 1 or 2 args only";
  }

  # Set the raw files.
  $self->raw( @fnames );

  # Set the filenames. Replace with processed images where appropriate
  my @paths;
  for my $f (@fnames) {
    my @internal = $self->_find_processed_images( $f );
    if (@internal) {
      push(@paths, @internal );
    } else {
      push(@paths, $f );
    }
  }

  # register these files
  for my $i (1..scalar(@paths) ) {
    $self->file($i, $paths[$i-1]);
  }

  # Populate the base header from the first file
  $self->readhdr($fnames[0]);

  # Find the group name and set it.
  $self->findgroup;

  # Find the recipe name.
  $self->findrecipe;

  # Find nsubs.
  $self->findnsubs;

  # Just return true.
  return 1;
}

=item B<data_detection_tasks>

Returns the names of the DRAMA tasks that should be queried for new
raw data.

  @tasks = $Frm->data_detection_tasks();

These tasks must be registered with the C<ORAC::Inst::Defn> module.

=cut

sub data_detection_tasks {
  my $self = shift;
  return ("QLSIM");
  my $pre = $self->_wavelength_prefix();
  my @codes = $self->_dacodes();

  # The task names will depend on the wavelength
  return map { "SCU2_$pre" . uc($_) } @codes;
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

Not implemented for SCUBA-2 because of the multiple files
that can be associated with a particular UT date and observation number:
the multiple sub-arrays (a to d) and the multiple subscans.

=cut

sub file_from_bits {
  my $self = shift;
  croak "file_from_bits Method not supported since the number of files per observation is not predictable.\n";
}

=item B<pattern_from_bits>

Determine the pattern for the raw filename given the variable component
parts. A prefix (usually UT) and observation number should be supplied.

  $pattern = $Frm->pattern_from_bits( $prefix, $obsnum );

Returns a regular expression object.

=cut

sub pattern_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  my $padnum = $self->_padnum( $obsnum );

  my $letters = '['.$self->_dacodes.']';

  my $pattern = $self->rawfixedpart . $letters . '_'. $prefix . "_" . 
     $padnum . '_\d\d\d\d\d' . $self->rawsuffix;

  return qr/$pattern/;
}


=item B<flag_from_bits>

Determine the flag filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  @fnames = $Frm->file_from_bits($prefix, $obsnum);

Returns multiple file names (one for each array) and
throws an exception if called in a scalar context. The filename
returned will include the path relative to ORAC_DATA_IN, where
ORAC_DATA_IN is the directory containing the flag files.

The format is "swxYYYYMMDD_NNNNN.ok", where "w" is the wavelength
signifier ('8' for 850 or '4' for 450) and "x" a letter from
'a' to 'd'.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  croak "flag_from_bits returns more than one flag file name and does not support scalar context (For debugging reasons)" unless wantarray;

  # pad with leading zeroes
  my $padnum = $self->_padnum( $obsnum );

  # get prefix
  my $fixed = $self->rawfixedpart();

  my @flags = map {
    $fixed . $_ . $prefix . "_$padnum" . ".ok"
  } ( $self->_dacodes );

  # SCUBA naming
  return @flags;
}

=item B<findgroup>

Return the group associated with the Frame. This group is constructed
from header information. The group name is automatically updated in
the object via the group() method.

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
#    $group = $self->hdr('MODE') .
#      $self->hdr('OBJECT');
    $group = "1";
  }

  # Update $group
  $self->group($group);

  return $group;
}


=item B<findnsubs>

Forces the object to determine the number of sub-frames
associated with the data by looking in the header (hdr()). 
The result is stored in the object using nsubs().


Unlike findgroup() this method will always search the header for
the current state.

=cut

sub findnsubs {
  my $self = shift;
  my @files = $self->raw;
  my $nsubs = scalar( @files );
  $self->nsubs( $nsubs );
  return $nsubs;
}


=item B<findrecipe>

Return the recipe associated with the frame.  The state of the object
is automatically updated via the recipe() method.

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
  }

  $recipe = 'QUICK_LOOK';

  # Update the recipe
  $self->recipe($recipe);

  return $recipe;
}

=back

=begin __INTERNAL_METHODS

=head1 PRIVATE METHODS

=over 4

=item B<_padnum>

Pad an observation number.

 $padded = $frm->_padnum( $raw );

=cut

sub _padnum {
  my $self = shift;
  my $raw = shift;
  return sprintf( "%05d", $raw);
}

=item B<_wavelength_prefix>

Return the relevent wavelength code that will be used to specify the
particular set of data files. An '8' for 850 microns and a '4' for 450
microns.

 $pre = $frm->_wavelength_prefix();

=cut

sub _wavelength_prefix {
  my $self = shift;
  my $code;
  if ($ENV{ORAC_INSTRUMENT} =~ /_LONG/) {
    $code = '8';
  } else {
    $code = '4';
  }
  return $code;
}

=item B<_dacodes>

Return the relevant Data Acquisition computer codes. Always a-d.

  @codes = $frm->_dacodes();
  $codes = $frm->_dacodes();

In scalar context returns a single string with the values concatenated.

=cut

sub _dacodes {
  my $self = shift;
  my @letters = qw/ a b c d /;
  return (wantarray ? @letters : join("",@letters) );
}

=item B<_find_processed_images>

Some SCUBA-2 data files include processed images (specifically, DREAM
and STARE) that should be used as the pipeline input images in preference
to the time series.

This method takes a single file and returns the HDS hierarchy to these
images within the main frame. Returns empty list if no reduced images
are present.

=cut

sub _find_processed_images {
  my $self = shift;
  my $file = shift;

  # begin error context
  my $status = &NDF::SAI__OK;
  err_begin( $status );

  # create the expected path to the container
  $file =~ s/\.sdf$//;
  my $path = $file . ".MORE.SCU2RED";

  # forget about using NDF to locate the extension, use HDS directly
  ($status, my @locs) = retrieve_locs( $path, 'READ', $status );

  # if status is bad, annul what we have and return empty list
  if ($status != &NDF::SAI__OK) {
    err_annul( $status );
    dat_annul( $_, $status ) for @locs;
    err_end( $status );
    return ();
  }

  # now count the components in this location
  dat_ncomp($locs[-1], my $ncomp, $status);

  my @images;
  if ($status == &NDF::SAI__OK) {
    for my $i ( 1..$ncomp ) {
      dat_index( $locs[-1], $i, my $iloc, $status );
      dat_name( $iloc, my $name, $status );
      push(@images, $path . "." . $name) if $name =~ /^I\d+$/;
      dat_annul( $iloc, $status );
    }
  }
  dat_annul( $_, $status ) for @locs;
  err_annul( $status ) if $status != &NDF::SAI__OK;
  err_end( $status );

  return @images;
}

=end __INTERNAL_METHODS

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
