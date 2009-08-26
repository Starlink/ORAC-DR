package ORAC::Calib;

=head1 NAME

ORAC::Calib - base class for selecting calibration frames in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Calib;

  $Cal = new ORAC::Calib;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;


=head1 DESCRIPTION

This module provides the basic methods available to all ORAC::Calib
objects.  This class should be used for selecting calibration frames.

Unless specified otherwise, a calibration frame is selected by first,
the nearest reduced frame; second, explicit specification via the
-calib command line option (handled by the pipeline); third, by search
of the appropriate index file.

Note this version: Index files not implemented.

=cut


# Calibration object for the ORAC pipeline

use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;
use ORAC::Index;
use ORAC::Print;
use ORAC::Inst::Defn qw/ orac_determine_calibration_search_path /;
use File::Spec;

$VERSION = '1.0';

# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a ORAC::Calib object.
The object identifier is returned.

  $Cal = new ORAC::Calib;

=cut

# NEW - create new instance of Calib.

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {};  # Anon hash reference
  $obj->{Thing1} = {};		# ditto
  $obj->{Thing2} = {};		# ditto

  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}

=back

=head2 Accessor Methods

=over 4

=cut

# Frossie's things
# ----------------

=item B<thing>

Returns the hash that can be used for checking the validity of
calibration frames. This is a combination of the two hashes
stored in C<thingone> and C<thingtwo>. The hash returned
by this method is readonly.

  $hdr = $Cal->thing;

=cut

sub thing {
  return { %{$_[0]->thingone}, %{$_[0]->thingtwo} };
}

=item B<thingone>

Returns or sets the hash associated with the header of the object
(frame or group or whatever) needed to match calibration criteria
against.

Ending sentences with a preposition is a bug.

=cut

sub thingone {

  my $self = shift;

  # check that we have been passed a hash
  if (@_) {
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Thing1} = $arg;
  }

  return $self->{Thing1};
}

=item B<thingtwo>

Returns or sets the hash associated with the user defined header of
the object (frame or group or whatever) against which calibration
criteria are applied.

=cut

sub thingtwo {

  my $self = shift;

  # check that we have been passed a hash
  if (@_) {
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Thing2} = $arg;
  }

  return $self->{Thing2};
}


=back

=head2 General Methods

=over 4

=item B<find_file>

Returns the full path and filename of the requested file (the first
file found in the search path).

  $filename = $Cal->find_file("fs_izjhklm.dat");

croaks if the file can not be found. It's likely that this is a bit
drastic but it will indicate something bad is going on before some
other unexpected behaviour occurs.  See
B<ORAC::Inst::Defn::orac_determine_calibration_search_path> for
information on setting up calibration directories.

=cut

sub find_file {
  my $self = shift;

  my $file = shift;
  croak "No file supplied to find_file() method"
    if ! defined $file;

  # Get the search path and also look in ORAC_DATA_OUT
  my @directories = ($ENV{ORAC_DATA_OUT},
                     orac_determine_calibration_search_path( $ENV{'ORAC_INSTRUMENT'} ));

  foreach my $directory (@directories) {
    if( -e ( File::Spec->catdir( $directory, $file ) ) ) {
      return File::Spec->catdir( $directory, $file );
    }
  }

  croak "Could not find '$file' in dirs ".join(",",@directories)
    ." (possible programming error or your environment variables are incorrect)";

}

=item B<retrieve_by_column>

Returns the value for the specified column in the specified index.

  $value = $Cal->retrieve_by_column( "readnoise", "ORACTIME" );

The first argument is a queryable 

=cut

sub retrieve_by_column {
  my $self = shift;
  my $index = shift;
  my $column = uc( shift );

  return if ! defined( $index );
  return if ! defined( $column );

  my $method = $index . "index";

  my $basefile = $self->$method->choosebydt('ORACTIME', $self->thing, 0 );
  croak "Unable to find suitable calibration data from $index"
    unless defined $basefile;

  my $ref = $self->$method->indexentry( $basefile );
  if( exists( $ref->{$column} ) ) {
    return $ref->{$column};
  }
  return;
}

=back

=head1 SEE ALSO

L<ORAC::Group> and
L<ORAC::Frame> 

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>, and
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
