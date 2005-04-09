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

Create a new instance of a B<ORAC::Frame::SCUBA2> object.  This method
also takes optional arguments: if 1 argument is supplied it is assumed
to be the name of the raw file associated with the observation but if
a reference to an array is supplied, each file listed in the array is
used. If 2 arguments are supplied they are assumed to be the raw file
prefix and observation number. In any case, all arguments are passed
to the configure() method which is run in addition to new() when
arguments are supplied.  The object identifier is returned.

   $Frm = new ORAC::Frame::SCUBA2;
   $Frm = new ORAC::Frame::SCUBA2("file_name");
   $Frm = new ORAC::Frame::SCUBA2(\@files);
   $Frm = new ORAC::Frame::SCUBA2("UT","number");

This method runs the base class constructor and then modifies
the rawsuffix and rawfixedpart to be '.sdf' and 's4' or 's8'
(depending on instrument designation) respectively.

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

Configure the frame object. Usually called from the constructor.

Can be called either with a single filename or a reference to an
array of filenames

  $Frm->configure( \@files );
  $Frm->configure( $file );

=cut

sub configure {
  my $self = shift;

  my @fnames;
  if( scalar( @_ ) == 1 ) {
    my $fnamesref = shift;
    @fnames = ( ref($fnamesref) ? @$fnamesref : $fnamesref );
  } elsif( scalar( @_ ) == 2 ) {

    # SCUBA-2 configure() cannot take 2 arguments.
    croak "configure() for SCUBA-2 cannot take two arguments";

  } else {
    croak "Wrong number of arguments to configure: 1 or 2 args only";
  }

  # Set the raw files.
  $self->raw( @fnames );

  # Read the fits headers from all the raw files (since they should all have
  # .FITS)
  my %rfits;
  for my $f (@fnames) {
    my $fits;
    eval {
      $fits = new Astro::FITS::Header::NDF( File => $f );
      $fits->tiereturnsref(1);
    };
    if ($@) {
      # should not happen in real data but may happen in simulated
      # data
      $fits = new Astro::FITS::Header( Cards => []);
    }
    $rfits{$f}->{PRIMARY} = $fits;
  }

  # Set the filenames. Replace with processed images where appropriate
  my @paths;
  for my $f (@fnames) {
    my @internal = $self->_find_processed_images( $f );
    if (@internal) {
      push(@paths, @internal );
      # and read the FITS headers
      my @hdrs;
      for my $i (@internal) {

	my $fits;
	eval {
	  $fits = new Astro::FITS::Header::NDF( File => $i );
	  $fits->tiereturnsref(1);
	};
	if ($@) {
	  # should not happen in real data but may happen in simulated
	  # data
	  $fits = new Astro::FITS::Header( Cards => []);
	}

	# Just store each one in turn. We can not index by a unique
	# name since I1 can be reused between files in the same frame
	push(@hdrs, $fits);
	
      }

      $rfits{$f}->{SECONDARY} = \@hdrs;

    } else {
      push(@paths, $f );
    }
  }

  # first thing we need to do is find which keys differ
  # between the .I1 and .IN processed images
  for my $f (keys %rfits) {

    # Rather than finding the unique keys of the primary and all the
    # secondary headers (Which may result in no headers that are
    # shared between primary and child) we first remove duplicate keys
    # from the child header and move them to the primary. In general
    # the secondary headers will either be completely unique keys
    # (otherwise they would be in the primary) or a complete copy
    # of the primary plus the unique keys.

    # in the former case, there will be no identical keys and so
    # nothing to merge into the PRIMARY header. In the latter, 95%
    # will probably be identical and that will probably be identical
    # to the bulk of the primary header.

    if (exists $rfits{$f}->{SECONDARY}) {
      # make sure we always return an entry in @different
      my ($same, @different) = $self->_merge_fits( { force_return_diffs => 1},
						   @{$rfits{$f}->{SECONDARY}});

      # differences should now be written to the SECONDARY array
      # since those are now the unique headers. We 
      $rfits{$f}->{SECONDARY} = \@different;

      # and merge the matching keys into the parent header
      # in this case, headers that are not present in either the child
      # or the primary header should be included in the merged header.
      my ($merged, $funique, $cunique) = $self->_merge_fits( { merge_unique => 1 }, 
							     $rfits{$f}->{PRIMARY}, $same);

      # Since we have merged unique keys into the primary header, anything
      # that is present in the "different" headers will be problematic since
      # it implies that we have headers that are present in both the .I
      # components and the primary header but that are identical between
      # the .I components yet different to the primary header. This is a 
      # problem and we need to issue a warning
      if (defined $funique || defined $cunique) {
	orac_warn("Headers are present in the primary FITS header of $f that clash with different values that are fixed amongst the processed components. This is not allowed.\n");
	
	orac_warn("Primary header:\n". $funique ."\n")
          if defined $funique;
	orac_warn("Component header:\n". $cunique ."\n")
          if defined $cunique;
      }

      # Now reset the PRIMARY header to be the merge
      $rfits{$f}->{PRIMARY} = $merged;
    }
  }

  # Now we need to merge the primary headers into a single
  # global header. We do not merge unique headers (there should not be
  # any anyway) as those should be pushed back down

  # merge in the original filename order

  my ($primary, @different) = $self->_merge_fits( map {
                                                   $rfits{$_}->{PRIMARY} 
						 } @fnames);

  # The leftovers have to be stored back into the subheaders
  # but we also need to extract subheaders
  my $stored_good;
  my @subhdrs;
  for my $i (0..$#fnames) {
    my $f = $fnames[$i];
    my $diff = $different[$i];

    if (exists $rfits{$f}->{SECONDARY}) {


      # merge with the child FITS headers if required
      if (defined $diff) {
	$stored_good = 1;
	push(@subhdrs, map { $_->splice(-1,0,$diff->allitems); $_ } 
	    @{ $rfits{$f}->{SECONDARY}});
      } else {
	# just store what we have (which may be empty)
	for my $h (@{$rfits{$f}->{SECONDARY}}) {
	  $stored_good = 1 if $h->sizeof > 0;
	  push(@subhdrs, $h);
	}
      }

    } else {
      # we only had a primary header so this is only defined if we have
      # a difference
      if (defined $diff) {
	$stored_good = 1; # indicate that we have at least one valid subhdr
	push(@subhdrs, $diff);
      } else {
	# store blank header
	push(@subhdrs, new Astro::FITS::Header( Cards => []));
      }
    }

  }

  # do we really have a subhdr?
  if ($stored_good) {
    if (@subhdrs != @paths) {
      orac_err("Error forming sub-headers from FITS information. The number of subheaders does not equal the number of file paths (".
	       scalar(@subhdrs) . " != " . scalar(@paths).")\n");
    }
    $primary->subhdrs( @subhdrs );
  }

  # Now make sure that the header is populated
  $self->fits( $primary );
  $self->calc_orac_headers;

  # register these files
  for my $i (1..scalar(@paths) ) {
    $self->file($i, $paths[$i-1]);
  }

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

=item B<_merge_fits>

Given a set of FITS objects, return a merged FITS header (with the
keys that have the same value and comment across all headers) and new
FITS headers for each input header containing the header items that
differ (including keys that are not present in all headers)

 ($same, @different) = $Frm->_merge_fits( \%options, $fits1, $fits2, ...);

@different can be empty if all headers match but if any headers are
different there will always be the same number of headers in
@different as supplied to the function. An empty list is returned if
not headers are supplied.

The options hash is itself optional. It contains the following keys:

 merge_unique - if a key is only present in one header, propogate
                to the merged header rather than retaining it.

 force_return_diffs - return an empty object per input header
                      even if there are no diffs

=cut

sub _merge_fits {
  my $self = shift;

  # optional options handling
  my %opt = ( merge_unique => 0,
	      force_return_diffs => 0,
	    );
  if (ref($_[0]) eq 'HASH') {
    my $o = shift;
    %opt = ( %opt, %$o );
  }

  # everything else is fits headers
  my @fits = @_;
  return () unless @fits;
  return $fits[0] unless @fits > 1;

  # Convert all the headers into cards for easy manipulation
  my @cards = map { [ $_->cards ]} @fits;

  # Now we need to find an easy way of comparing the concatenated header
  # with individual header. We do this by forming a hash for each header
  # with the card as the keyword and the value as the original location
  # of that keyword in the header. We store these hashes in an array
  # in the same order as the original headers.
  my @cardhash;
  for my $f (@cards) {
    # the card is the hash key and the value is the location in the
    # original array
    my $i = 0;
    my %keys = map { $_, $i++ } @$f;
    push(@cardhash, \%keys);
  }

  # Now we need to generate an array of all the unique cards we
  # have available to us in the order we were given them originally.
  # We can not use a simple hash directly. We use "existence" to control
  # whether or not to store the card
  my %allcards;
  my @unique;
  # loop over each header (we could optimize by assuming the fits header
  # only has unique cards)
  for my $h (@cards) {
    # loop over individual cards
    for my $c (@$h) {
      if (!exists $allcards{$c}) {
	$allcards{$c}++;
	push(@unique, $c);
      }
    }
  }

  # and loop over them all to get the merged header (we already can work
  # out the coverage by looking at %allcards but we need to know where
  # a card came from if it is only in one or two places)
  my @merge;
  for my $c (@unique) {

    # does the card exist?
    my $exists = grep { exists $_->{$c} } @cardhash;

    if ($exists == scalar(@cardhash) ||
	($opt{merge_unique} && $exists == 1) ) {
      # We have match across all inputs or a unique match
      # so store it in the merged header
      push(@merge, $c);

      # and remove it from each of the input headers
      for my $i (0..$#cards) {
	# can not delete it yet (we do not want the count to change)
	# so undef the value
	# merge_unique==true does allow this to trigger without a
	# corresponding lookup existing
	my $index = (exists $cardhash[$i]->{$c} ? $cardhash[$i]->{$c} : undef);
	next unless defined $index;
	$cards[$i]->[$index] = undef;
      }
    }

  }

  # filter out the undef values
  for my $c (@cards) {
    @$c = grep { defined $_ } @$c;
  }

  # and clear @cards in the special case where none have any headers
  if (!$opt{force_return_diffs}) {
    @cards = () unless grep { @$_ != 0 } @cards;
  }

  # convert back to FITS object
  my $same = new Astro::FITS::Header( Cards => \@merge );
  my @diff = map { new Astro::FITS::Header( Cards => $_ ) } @cards;

  return ($same, @diff);
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

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
