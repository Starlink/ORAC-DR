package ORAC::Calib::NIRI;

=head1 NAME

ORAC::Calib::NIRI;

=head1 SYNOPSIS

  use ORAC::Calib::NIRI;

  $Cal = new ORAC::Calib::NIRI;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying NIRI-specific calibration
objects.  It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.  Written for Michelle and adapted for NIRI.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Calib::CGS4;			# use base class
use ORAC::Print;

use File::Spec;

use base qw/ORAC::Calib::CGS4/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


=head1 METHODS

=head2 Index and Rules files

For NIRI some of the rules files are keyed on the current value of
the CAMERA FITS header item.  This sub-class automatically changes the
rules file of the underlying index object.

=over 4

=item B<flatindex>

Uses F<rules.flat_im> and <rules.flat_sp>, and sets the index
file for imaging mode to be F<index.flat_im> and for spectroscopy
and IFU to be F<index.flat_sp>.

=cut


sub flatindex {
  my $self = shift;

  if (@_) { $self->{FlatIndex} = shift; }

# There is no direct keyword for the observation mode, so test for
# the presence of a grism.
  if ( uc( $self->thing->{FILTER3}) =~ /[Gg]rism/ ) {
    $self->flatindex_sp( $self->{FlatIndex} );
  } else {
    $self->flatindex_im( $self->{FlatIndex} );
  }
  return $self->{FlatIndex};

}

sub flatindex_im {
  my $self = shift;

  if ( @_ ) { $self->{FlatIndex} = shift; }

  if ( !defined( $self->{FlatIndex} ) ||
       $self->{FlatIndex}->indexfile !~ /_im$/ ) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.flat_im" );
    my $rulesfile = $self->find_file("rules.flat_im");
    $self->{FlatIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{FlatIndex};
}

sub flatindex_sp {
  my $self = shift;

  if ( @_ ) { $self->{FlatIndex} = shift; }

  if ( !defined( $self->{FlatIndex} ) ||
       $self->{FlatIndex}->indexfile !~ /_sp$/ ) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.flat_sp" );
    my $rulesfile = $self->find_file("rules.flat_sp");
    $self->{FlatIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{FlatIndex};
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

  my $ok = $self->maskindex->verify($self->maskname,$self->thing);

  # happy ending
  return $self->maskname if $ok;

  croak ("Override mask is not suitable! Giving up") if $self->masknoupdate;

  if (defined $ok) {

    my $mask = $self->maskindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $mask) {

      # Nothing suitable, default to fallback position
      # Check that exists and be careful not to set this as the
      # maskname() value since it has no corresponding index enrty
      my $defmask = $self->find_file("bpm.sdf");
      if( defined( $defmask ) ) {
        $defmask =~ s/\.sdf//;
        return $defmask;
      }

      # give up...
      croak "No suitable bad pixel mask was found in index file"
    }

    # Store the good value
    $self->maskname($mask);

  } else {

    # All fall down....
    croak("Error in determining bad pixel mask - giving up");
  }

}



=head2 New methods

=over 4

=item B<_set_index_rules>

Internal method to modify the state of an index object to reflect
the camera mode of NIRI.

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
  if ( uc( $self->thing->{FILTER3}) !~ /[Gg]rism/ ) {
    $index->indexrulesfile($im)
      unless $im eq $current;
  } else {
    $index->indexrulesfile($sp)
      unless $sp eq $current;
  }
  # and return the object
  return $index;
}

=item B<arlinesname>

Return (or set) the name of the current arlines.lis file - no checking

  $arlines = $Cal->arlinesname;

=cut

sub arlinesname {
  my $self = shift;
  if (@_) { $self->{Arlines} = shift; }
  return $self->{Arlines};
}


=item B<arlines>

Returns the name of a suitable arlines file.

=cut


sub arlines {

  my $self = shift;
  if (@_) {
    return $self->arlinesname(shift);
  };

  my $ok = $self->arlinesindex->verify($self->arlinesname,$self->thing);

  # happy ending
  return $self->arlinesname if $ok;

  if (defined $ok) {
    my $arlines = $self->arlinesindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $arlines) {
      # Nothing suitable, give up...
      croak "No suitable arlines file was found in index file"
    }

    # Store the good value
    $self->arlinesname($arlines);

  } else {
    # All fall down....
    croak("Error in determining arlines file - giving up");
  }
}



=item B<arlinesindex>

Returns the index object associated with the arlines index file. 
The index is static, therefore it resides in the calibration directory.

=cut

sub arlinesindex {

    my $self = shift;
    if (@_) { $self->{ArlinesIndex} = shift; }
    
    unless (defined $self->{ArlinesIndex}) {
      my $indexfile = $self->find_file("index.arlines");
      my $rulesfile = $self->find_file("rules.arlines");
      $self->{ArlinesIndex} = new ORAC::Index($indexfile,$rulesfile);
    }

    return $self->{ArlinesIndex}; 
}

=item B<calibratedarc>

Returns the name of a suitable calibrated arc file. If no suitable calibrated
arc file can be found, this method returns <undef> rather than croaking as
other calibration options do. This is so this calibration can be skipped if
no calibration arc can be found.

=cut

sub calibratedarc {
  my $self = shift;
  if (@_) {
    return $self->calibratedarcname(shift);
  };

  my $ok = $self->calibratedarcindex->verify($self->calibratedarcname,$self->thing);

  # happy ending
  return $self->calibratedarcname if $ok;

  if (defined $ok) {
   my $calibratedarc = $self->calibratedarcindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $calibratedarc) {
      # Nothing suitable, return undef.
      return undef;
    }

    # Store the good value
    $self->calibratedarcname($calibratedarc);

  } else {
    # Nothing suitable, return undef.
    return undef;
  }
}

=item B<calibratedarcindex>

Returns the index object associated with the calibratedarc index file.
Index is static and therefore in calibration directory.

=cut

sub calibratedarcindex {
  my $self = shift;
  if ( @_ ) { $self->{CalibratedArcIndex} = shift; }

  unless ( defined( $self->{CalibratedArcIndex} ) ) {
    my $indexfile = $self->find_file("index.calibratedarc");
    my $rulesfile = $self->find_file("rules.calibratedarc");
    $self->{CalibratedArcIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{CalibratedArcIndex};
}

=item B<calibratedarcname>

Return (or set) the name of the current calibrated arc file - no checking.

  $calibratedarc = $Cal->calibratedarcname;

=cut

sub calibratedarcname {
  my $self = shift;
  if ( @_ ) { $self->{CalibratedArc} = shift; }
  return $self->{CalibratedArc};
}


=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
