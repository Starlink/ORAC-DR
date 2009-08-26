package ORAC::Calib::Michelle;

=head1 NAME

ORAC::Calib::Michelle;

=head1 SYNOPSIS

  use ORAC::Calib::Michelle;

  $Cal = new ORAC::Calib::Michelle;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying Michelle-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Spec;
use File::Copy;

use base qw/ORAC::Calib::ImagSpec/;

use vars qw/$VERSION/;
$VERSION = '1.0';


=head1 METHODS

=head2 Index and Rules files

=over 4


=back

=head2 Accessor Methods

=over 4

=item B<flatindex>

Uses F<rules.flat_im> and <rules.flat_sp>

But indexfile is "index.flat".

=cut


sub flatindex {
  my $self = shift;
  my $index = $self->SUPER::flatindex;
  $self->_set_index_rules($index, 'rules.flat_im', 'rules.flat_sp');
}

=item B<emisname>

Return (or set) the name of the current emissivity frame - no checking

  $emis = $Cal->emisname;

=cut

sub emisname {
  my $self = shift;
  if( @_ ) { $self->{Emissivity} = shift unless $self->emisnoupdate; }
  return $self->{Emissivity};
}

=item B<emis>

Return (or set) the name of the curent emissivity frame - checks
suitability on return.

=cut

sub emis {
  my $self = shift;
  if( @_ ) {
    return $self->emisname( shift );
  };

  my $ok = $self->emisindex->verify( $self->emisname, $self->thing );

  if( $ok ) { return $self->emisname };

  croak("Override emissivity frame is not suitable. Giving up") if $self->emisnoupdate;

  if( defined $ok ) {
    my $emis = $self->emisindex->choosebydt( 'ORACTIME', $self->thing );
    croak "No suitable emissivity calibration was found in the index file"
      unless defined $emis;
    $self->emisname( $emis );
  } else {
    croak("Error in emissivity calibration checking - giving up");
  }
}

=item B<emisnoupdate>

Stops emissivity calibration object from updating itself with more
recent data. Used when using a command-line override to the pipeline.

=cut

sub emisnoupdate {
  my $self = shift;
  if( @_ ) { $self->{EmissivityNoUpdate} = shift; }
  return $self->{EmissivityNoUpdate};
}

=item B<emisindex>

Return (or set) the index object associated with the emissivity index file.

=cut

sub emisindex {
  my $self = shift;
  if( @_ ) { $self->{EmissivityIndex} = shift; }

  unless( defined $self->{EmissivityIndex} ) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.emis" );
    my $rulesfile = $self->find_file("rules.emis");
    $self->{EmissivityIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{EmissivityIndex};
}

=back

=head2 General Methods

=over 4

=item B<maskindex>

Returns the index object associated with the mask index file. The mask
index file is date-dependant if we don't already have a mask index file
in $ORAC_DATA_OUT.

=cut

sub maskindex {
  my $self = shift;
  if( @_ ) { $self->{MaskIndex} = shift; }

  unless( defined( $self->{MaskIndex} ) ) {

# Copy the index file from ORAC_DATA_CAL into ORAC_DATA_OUT, unless
# it already exists there. Then use the one in ORAC_DATA_OUT.
    if ( ! -e File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.mask" ) ) {
      copy( $self->find_file("index.mask"),
            File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.mask" ) );
    }
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.mask" );

# The rules file is always in $ORAC_DATA_CAL.
    my $rulesfile = $self->find_file("rules.mask");

    $self->{MaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{MaskIndex};

}

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
