package ORAC::Frame::IRIS2;

=head1 NAME

ORAC::Frame::IRIS2 - Class for dealing with IRIS2 observation frames

=head1 SYNOPSIS

  use ORAC::Frame::IRIS2;

  $Frm = new ORAC::Frame::IRIS2("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to IRIS2. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available to
B<ORAC::Frame::IRIS2> objects.

The class only deals with the NDF form of IRIS2 data rather than the
native FITS format (the pipeline forces a conversion as soon as the
data are located).

=cut

use 5.006;
use warnings;
use strict;
use Carp;
use ORAC::Print qw/orac_warn/;

our $VERSION;

use base qw/ORAC::Frame::NDF/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

use ORAC::Constants;

# Bring in Math::Trig::acos for the header translation tables.
use Math::Trig qw/ acos /;

*pattern_from_bits = \&file_from_bits;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::IRIS2> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::IRIS2;
   $Frm = new ORAC::Frame::IRIS2("file_name");
   $Frm = new ORAC::Frame::IRIS2("UT","number");

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
  $self->rawfixedpart('_raw');
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

IRIS2 file name convention is

  DDmmmNNNN.fits

where DD is the day number, mmm is the first 3 letters of the
month and NNNN is the zero-padded observation number. e.g

  23mar0001.fits

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes - 5(!) digit obsnum
  # Could use sprintf
  my $padnum = '0'x(4-length($obsnum)) . $obsnum;

  my $month = substr($prefix, 4, 2);
  my $day   = substr($prefix, 6, 2);

  my @months = qw/ jan feb mar apr may jun jul aug sep oct nov dec/;
  $prefix = $day . $months[$month-1];

  # IRIS2 naming
  return $prefix . $padnum . $self->rawsuffix;
}



=item B<findgroup>

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

The group name stored in the object is automatically updated using 
this value.

=cut

sub findgroup {

  my $self = shift;

  my $amiagroup;
  my $hdrgrp;

  if( defined $self->hdr('IR2GNUM') ) {
    $hdrgrp = $self->hdr('IR2GNUM');
#    print "Using IRIS2 user specified IR2GNUM. group=$hdrgrp\n";
    if ($self->hdr('IR2GMEM')) {
      $amiagroup = 1;
    } elsif (!defined $self->hdr('IR2GMEM')){
      $amiagroup = 1;
    } else {
      $amiagroup = 0;
    }
  } else {
    $hdrgrp = $self->hdr('GRPNUM');
#    print "Using usual GRPNUM. group=$hdrgrp\n";
    if ($self->hdr('GRPMEM')) {
      $amiagroup = 1;
    } elsif (!defined $self->hdr('GRPMEM')){
      $amiagroup = 1;
    } else {
      $amiagroup = 0;
    }
  }

  # Is this group name set to anything useful
  if (!$hdrgrp || !$amiagroup ) {
    # if the group is invalid there is not a lot we can do about
    # it except for the case of certain calibration objects that
    # we know are the only members of their group (eg DARK)

#    if ($self->hdr('OBJECT') eq 'DARK') {
       $hdrgrp = 0;
#    }

  }

  $self->group($hdrgrp);

  return $hdrgrp;

}

=item B<gui_id>

Returns the identification string that is used to compare the
current frame with the frames selected for display in the
display definition file.

Arguments:

 number - the file number (as accepted by the file() method)
          Starts counting at 1. If no argument is supplied
          a 1 is assumed.

To return the ID associated with the second frame:

 $id = $Frm->gui_id(2);

If nfiles() equals 1, this method returns everything after the last
suffix (using an underscore) from the filename stored in file(1). If
nfiles E<gt> 1, this method returns everything after the last
underscore, prepended with 's$number'. ie if file(2) is test_dk, the
ID would be 's2dk'; if file() is test_dk (and nfiles = 1) the ID would
be 'dk'. A special case occurs when the suffix is purely a number (ie
the entire string matches just "\d+"). In that case the number is
translated to a string "num" so the second frame in "c20010108_00024"
would return "s2num" and the only frame in "f2001_52" would return
"num".

Returns C<undef> if the file name is not defined.

=cut

sub gui_id {
  my $self = shift;

  # Read the number
  my $num = 1;
  if (@_) { $num = shift; }

  # Retrieve the Nth file name (start counting at 1)
  my $fname = $self->file($num);
  return unless defined $fname;

  # IRIS2 uses a different file convention than UKIRT instruments,
  # so we need to determine the ID differently.

  # First, split on underscore to see if there's a suffix (i.e. _dk)
  my $id;
  my (@split) = split(/_/,$fname);
  if(scalar(@split) > 1) {
    $id = $split[-1];
  } else {

    # No suffix, so parse the filename as DDmmmYYYYY
    $fname =~ /^\d\d[a-zA-Z]{3}(\d{4})/;
    $id = $1;
  }

  # If we have a number translate to "num"
  $id = "num" if ($id =~ /^\d+$/);

  # Find out how many files we have
  my $nfiles = $self->nfiles;

  # Prepend wtih s$num if nfiles > 1
  # This is to make it simple for instruments that only ever
  # store one frame (eg UFTI)
  $id = "s$num" . $id if $nfiles > 1;

  return $id;

}

=item B<inout>

Method to return the current input filename and the new output
filename given a suffix. The input filename is chopped at the
underscore and the suffix appended. The suffix is simply appended
if there is no underscore.

Note that this method does not set the new output name in this
object. This must still be done by the user.

Returns $in and $out in an array context:

   ($in, $out) = $Frm->inout($suffix);

Returns $out in a scalar context:

   $out = $Frm->inout($suffix);

Therefore if in=file_db and suffix=_ff then out would
become file_db_ff but if in=file_db_ff and suffix=dk then
out would be file_db_dk.

An optional second argument can be used to specify the
file number to be used. Default is for this method to process
the contents of file(1).

  ($in, $out) = $Frm->inout($suffix, 2);

will return the second file name and the name of the new output
file derived from this.

The last suffix is not removed if it consists solely of numbers.
This is to prevent truncation of raw data filenames.

=cut

sub inout {

  my $self = shift;

  my $suffix = shift;

  # Read the number
  my $num = 1; 
  if (@_) { $num = shift; }

  my $infile = $self->file($num);

  # Chop off at last underscore
  # Must be able to do this with a clever pattern match
  # Want to use s/_.*$// but that turns a_b_c to a and not a_b

  # instead split on underscore and recombine using underscore
  # but ignoring the last member of the split array
  my ($junk, $fsuffix) = $self->_split_fname( $infile );

  # Suffix is ignored
  my @junk = @$junk;

  # With IRIS2, we want to drop everything after the underscore.
  if ($#junk > 0) {
    @junk = @junk[0..$#junk-1];
  }

  # Need to strip a leading underscore if we are using join_name
  $suffix =~ s/^_//;
  push(@junk, $suffix);

  my $outfile = $self->_join_fname(\@junk, '');

  # Generate a warning if output file equals input file
  orac_warn("inout - output filename equals input filename ($outfile)\n")
    if ($outfile eq $infile);

  return ($infile, $outfile) if wantarray();  # Array context
  return $outfile;                            # Scalar context
}

=item B<mergehdr>

Dummy method.

  $frm->mergehdr();

=cut

sub mergehdr {

}

=item B<template>

Method to change the current filename of the frame (file())
so that it matches a template. e.g.:

  $Frm->template("something_number_flat");

Would change the first file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

  $Frm->template("something_number_dark", 2);

would change the second filename to match "something_number_dark".
The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

The Nth filename is modified (ie file(N)).
There are no return arguments.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $fnum = 1;
  if (@_) { $fnum = shift; };

  my $num = $self->number;
  my $padnum = '0'x(4-length($num)) . $num;

  # Change the first number
  $template =~ s/^(\w{5})(\d{4})_/$1${padnum}_/;

  # Update the filename
  $self->file($fnum, $template);

}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
