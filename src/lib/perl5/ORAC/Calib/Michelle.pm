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

use ORAC::Calib::CGS4;			# use base class
use ORAC::Print;

use File::Spec;
use File::Copy;

use base qw/ORAC::Calib::CGS4/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


=head1 METHODS

=head2 Index and Rules files

For Michelle some of the rules files are keyed on the
current value of the CAMERA FITS header item. This sub-class
automatically changes the rules file of the underlying index
object.

=over 4

=item B<flatindex>

Uses F<rules.flat_im> and <rules.flat_sp>

=cut


sub flatindex {
  my $self = shift;
  my $index = $self->SUPER::flatindex;
  $self->_set_index_rules($index, 'rules.flat_im', 'rules.flat_sp');
}

=item B<skyindex>

Uses F<rules.sky_im> and <rules.sky_sp>

=cut


sub skyindex {
  my $self = shift;
  my $index = $self->SUPER::skyindex;
  $self->_set_index_rules($index, 'rules.sky_im', 'rules.sky_sp');
}


=back

=head2 Accessor Methods

=over 4

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

=item B<mask>

Return (or set) the name of the current mask. If a mask is to be returned 
every effrort is made to guarantee that the mask is suitable for use.

  $mask = $Cal->mask;
  $Cal->mask($newmask);

If no suitable mask can be found from the index file (or the currently
set mask is not suitable), C<$ORAC_DATA_CAL/bpm> is returned by
default (so long as the file does exist).  Note that a test for
suitability can not be performed since there is no corresponding index
entry for this default mask.

=cut


sub mask {

  my $self = shift;

  if (@_) {
    return $self->maskname(shift);
  };

  return $self->maskname if $self->masknoupdate;

# Ignore distracting warnings.
  my $warn = 0;
  my $ok = $self->maskindex->verify( $self->maskname, $self->thing, $warn );

# happy ending
  return $self->maskname if $ok;

  if (defined $ok) {

    my $mask = $self->maskindex->chooseby_negativedt( 'ORACTIME', $self->thing, $warn );
    unless (defined $mask) {
      # Nothing suitable, default to fallback position
      # Check that exists and be careful not to set this as the
      # maskname() value since it has no corresponding index enrty
      my $defmask = $self->find_file("bpm.sdf");

      # If we're in spectroscopy mode, over-ride this to be bpm_sp
      # $uhdrref is a reference to the Frame uhdr hash
      my $uhdrref = $self->thingtwo;
      if ($uhdrref->{'ORAC_OBSERVATION_MODE'} eq 'spectroscopy') {
        $defmask = $self->find_file("bpm_sp.sdf");
      }
      if( defined( $defmask ) ) {
        $defmask =~ s/\.sdf$//;
        return $defmask;
      }

      # give up...
      croak "No suitable bad pixel mask was found in index file"
    }

    # Replace tokens if necessary.
    $mask =~ s/\+(\w+)\+/$ENV{$1}/eg;

    # Store the good value
    $self->maskname( $mask );

  } else {

    # All fall down....
    croak("Error in determining bad pixel mask - giving up");
  }

}

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

=head2 New methods

=over 4

=item B<_set_index_rules>

Internal method to modify the state of an index object to reflect
the camera mode of Michelle.

  $Cal->_set_index_rules($index, $imaging_rules, $spec_rules);

ORAC_DATA_CAL is prepended if no path is provided.

Returns the index object.

=cut

sub _set_index_rules {

  my $self = shift;
  my $index = shift;
  my $im = shift;
  my $sp = shift;

  # Prefix ORAC_DATA_CAL if required
  # This is non-portable (kluge)
  $im = $self->find_file($im)
    unless $im =~ /\//;
  $sp = $self->find_file($sp)
    unless $sp =~ /\//;

  # Get the current name of the rules file in case we don't need to
  # update it
  my $current = $index->indexrulesfile;

  # Now change the rules file
  if (uc($self->thing->{CAMERA}) eq 'IMAGING') {
    $index->indexrulesfile($im)
      unless $im eq $current;
  } else {
    $index->indexrulesfile($sp)
      unless $sp eq $current;
  }
  # and return the object
  return $index;
}


=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
