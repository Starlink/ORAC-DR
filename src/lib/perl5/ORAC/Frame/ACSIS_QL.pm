package ORAC::Frame::ACSIS_QL;

=head1 NAME

ORAC::Frame::ACSIS_QL - Class for dealing with ACSIS quick-look cubes.

=head1 SYNOPSIS

use ORAC::Frame::ACSIS_QL;

$Frm = new ORAC::Frame::ACSIS_QL(\@filenames);
$Frm->file("file");
$Frm->readhdr;
$Frm->configure;
$value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to ACSIS. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available to
B<ORAC::Frame::IRIS2> objects.

=cut

use 5.006;
use warnings;
use strict;
use Carp;

use ORAC::Error qw/ :try /;
use ORAC::Print qw/ orac_warn /;

our $VERSION;

use base qw/ ORAC::Frame::NDF /;

$VERSION = '1.0';

use ORAC::Constants;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of an B<ORAC::Frame::ACSIS_QL> object. This method
also takes optional arguments:

=over 8

=item * If one argument is supplied it is assumed to be a reference
to an array containing a list of raw files associated with the
observation.

=item * If two arguments are supplied they are assumed to be the
UT date and observation number.

=back

In any case, all arguments are passed to the configure() method which
is run in addition to new() when arguments are supplied.

The object identifier is returned.

  $Frm = new ORAC::Frame::ACSIS_QL;
  $Frm = new ORAC::Frame::ACSIS_QL( \@files );
  $Frm = new ORAC::Frame::ACSIS_QL( '20040919', '10' );

The constructor hard-wires the '.sdf' rawsuffix and the 'a' prefix,
although these can be overridden with the rawsuffix() and
rawfixedpart() methods.

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
  $self->rawfixedpart('ac');
  $self->rawformat('NDF');
  $self->rawsuffix('.sdf');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object.
  # Currently the argument will be the array reference to the list
  # of filenames, or if there are two args it's the UT date and
  # observation number.
  $self->configure(@_) if @_;

  return $self;
}

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument.
The file(), raw(), readhdr(), findgroup(), findrecipe() and
findnsubs() methods are invoked by this command. Arguments are
required. If there is one argument it is assumed that this
is a reference to an array containing a list of raw filenames.
The ACSIS_QL version of configure() cannot take two parameters,
as there is no way to know the location of the file that would
make up the Frame object from only the UT date and run number.

  $Frm->configure(\@files);

=cut

sub configure {
  my $self = shift;

  my @fnames;
  if( scalar( @_ ) == 1 ) {
    my $fnamesref = shift;
    @fnames = (ref $fnamesref ? @$fnamesref : $fnamesref);
  } elsif( scalar( @_ ) == 2 ) {

    # ACSIS_QL configure() cannot take 2 arguments.
    croak "configure() for ACSIS_QL cannot take two arguments";

  } else {
    croak "Wrong number of arguments to configure: 1 or 2 args only";
  }

  # Set the filenames.
  for my $i (1..scalar(@fnames)) {
    $self->file($i, $fnames[$i-1]);
  }

  # Set the raw files.
  $self->raw( @fnames );

  # Populate the header.
  $self->readhdr;

  # Find the group name and set it.
  $self->findgroup;

  # Find the recipe name.
  $self->findrecipe;

  # Find nsubs.
  $self->findnsubs;

  # Just return true.
  return 1;
}

=back

=head2 General Methods

=over 4


=item B<file_from_bits>

There is no file_from_bits() for ACSIS_QL. Use pattern_from_bits()
instead.

=cut

sub file_from_bits {
  die "ACSIS_QL has no file_from_bits() method. Use pattern_from_bits() instead\n";
}

=item B<flag_from_bits>

Determine the name of the flag file given the variable component
parts. A prefix (usually UT) and observation number should be
supplied.

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

For ACSIS_QL the flag file is of the form .aYYYYMMDD_NNNNN.ok, where
YYYYMMDD is the UT date and NNNNN is the observation number zero-padded
to five digits. The flag file is stored in $ORAC_DATA_IN/acsis00,
so the flag file will have the "acsis00" directory prepended to
it.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # Pad the observation number with leading zeros to make it five
  # digits long.
  my $padnum = '0'x(5-length($obsnum)) . $obsnum;

  my $flag = File::Spec->catfile('.' . $self->rawfixedpart . $prefix . '_' . $padnum . '.ok');

  return $flag;
}

=item B<findgroup>

Returns the group name from the header.

The group name stored in the object is automatically updated using
this value.

=cut

sub findgroup {
  my $self = shift;

  my $hdrgrp;
  if( defined( $self->hdr('DRGROUP') ) ) {
    $hdrgrp = $self->hdr('DRGROUP');
  } else {
    # Construct group name.

    $self->read_wcs;
    my $wcs = $self->wcs;

    my $restfreq = $wcs->GetC("RestFreq");

    $hdrgrp = $self->hdr( "OBJECT" ) .
              $self->hdr( "BWMODE" ) .
              $self->hdr( "INSTRUME" ) .
              $self->hdr( "OBS_TYPE" ) .
              $restfreq;
  }

  $self->group($hdrgrp);

  return $hdrgrp;
}

=item B<findnsubs>

Find the number of sub-frames associated by the frame by looking
at the list of raw files associated with object. Usually run
by configure().

  $nsubs = $Frm->findnsubs;

The state of the object is updated automatically.

=cut

sub findnsubs {
  my $self = shift;
  my @files = $self->raw;
  my $nsubs = scalar( @files );
  $self->nsubs( $nsubs );
  return $nsubs;
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

  my $padnum = '0'x(5-length($obsnum)) . $obsnum;

  my $pattern = $self->rawfixedpart . $prefix . "_" . $padnum . '_\d\d_\d\d' . $self->rawsuffix;

  return qr/$pattern$/;
}

=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number after the UT date in the
filename. This method is subclassed for ACSIS_QL.

The return value is -1 if no number can be determined.

=cut

sub number {
  my $self = shift;
  my $number;

  my $raw = $self->raw;
  if( defined( $raw ) &&
      $raw =~ /(\d+)_(\d\d)_(\d\d)(\.\w+)?$/ ) {
    # Drop leading zeroes.
    $number = $1 * 1;
  } else {
    # No match so set to -1.
    $number = -1;
  }
  return $number;
}

=back

=head1 SEE ALSO

L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;
