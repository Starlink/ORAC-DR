package ORAC::Calib::UIST;

=head1 NAME

ORAC::Calib::UIST;

=head1 SYNOPSIS

  use ORAC::Calib::UIST;

  $Cal = new ORAC::Calib::UIST;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying UIST-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects. Written for Michelle and adpated for UIST.

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

For Michelle and UIST some of the rules files are keyed on the
current value of the CAMERA FITS header item. This sub-class
automatically changes the rules file of the underlying index
object.

=over 4

=item B<standardindex>

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
      my $defmask = $ENV{ORAC_DATA_CAL} . "/bpm";
      return $defmask if -e $defmask . ".sdf";

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
the camera mode of Michelle or UIST.

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
  $im = File::Spec->catfile($ENV{ORAC_DATA_CAL}, $im)
    unless $im =~ /\//;
  $sp = File::Spec->catfile($ENV{ORAC_DATA_CAL}, $sp)
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

Returns the index object associated with the arlines index file. Index is 
static therefore in calibration directory.

=cut

sub arlinesindex {

    my $self = shift;
    if (@_) { $self->{ArlinesIndex} = shift; }
    
    unless (defined $self->{ArlinesIndex}) {
	my $indexfile = $ENV{ORAC_DATA_CAL}."/index.arlines";
	my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.arlines";
	$self->{ArlinesIndex} = new ORAC::Index($indexfile,$rulesfile);
    }

    return $self->{ArlinesIndex}; 
}






=item B<iarname>

Return (or set) the name of the current Iarc file - no checking

  $iar = $Cal->iarname;


=cut

sub iarname {
  my $self = shift;
  if (@_) { $self->{Iar} = shift; }
  return $self->{Iar};
}


=item B<iar>

Returns the name of a suitable Iarc file.

=cut


sub iar {

  my $self = shift;
  if (@_) {
    return $self->iarname(shift);
  };

  my $ok = $self->iarindex->verify($self->iarname,$self->thing);

  # happy ending
  return $self->iarname if $ok;

  if (defined $ok) {

    my $iar = $self->iarindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $iar) {

      # Nothing suitable, give up...
      croak "No suitable Iarc file was found in index file"
    }

    # Store the good value
    $self->iarname($iar);

  } else {

    # All fall down....
    croak("Error in determining Iarc file - giving up");
  }
}



=item B<iarindex>

Returns the index object associated with the iar file. 

=cut

sub iarindex {

    my $self = shift;
    if (@_) { $self->{IarIndex} = shift; }
    
    unless (defined $self->{IarIndex}) {
	my $indexfile = "index.iar";
	my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.iar";
	$self->{IarIndex} = new ORAC::Index($indexfile,$rulesfile);
    }

    return $self->{IarIndex}; 
}



=item B<grismname>

Return (or set) the name of the current grism data file - no checking

  $arlines = $Cal->grismname;


=cut

sub grismname {
  my $self = shift;
  if (@_) { $self->{Grism} = shift; }
  return $self->{Grism};
}


=item B<grism>

Returns the name of a suitable grism data file.

=cut


sub grism {

  my $self = shift;
  if (@_) {
    return $self->grismname(shift);
  };

  my $ok = $self->grismindex->verify($self->grismname,$self->thing);

  # happy ending
  return $self->grismname if $ok;

  if (defined $ok) {

    my $grism = $self->grismindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $grism) {

      # Nothing suitable, give up...
      croak "No suitable grism data file was found in index file"
    }

    # Store the good value
    $self->grismname($grism);

  } else {

    # All fall down....
    croak("Error in determining grism data file - giving up");
  }
}



=item B<grismindex>

Returns the index object associated with the grism index file. Index is 
static therefore in calibration directory.

=cut

sub grismindex {

    my $self = shift;
    if (@_) { $self->{GrismIndex} = shift; }
    
    unless (defined $self->{GrismIndex}) {
	my $indexfile = $ENV{ORAC_DATA_CAL}."/index.grism";
	my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.grism";
	$self->{GrismIndex} = new ORAC::Index($indexfile,$rulesfile);
    }

    return $self->{GrismIndex}; 
}



=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
adapted for UIST by S Todd (Dec 2001)

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
