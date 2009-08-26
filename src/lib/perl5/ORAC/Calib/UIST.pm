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
objects. It provides a class derived from ORAC::Calib::ImagSpec.  All the
methods available to ORAC::Calib::ImagSpec objects are available to
ORAC::Calib::UIST objects. Written for Michelle and adpated for UIST.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Spec;

use base qw/ORAC::Calib::ImagSpec/;

use vars qw/$VERSION/;
$VERSION = '1.0';


=head1 METHODS

=head2 General Methods

=over 4

=item B<ifuprofile>

=cut

sub ifuprofile {
  my $self = shift;
  if( @_ ) {
    return $self->ifuprofilename( @_ );
  }

  my $ok = $self->ifuprofileindex->verify( $self->ifuprofilename, $self->thing );

  return $self->ifuprofilename if $ok;

  if( defined( $ok ) ) {
    my $ifuprofile = $self->ifuprofileindex->chooseby_negativedt( "ORACTIME", $self->thing );

    if( ! defined( $ifuprofile ) ) {
      croak "No suitable IFU profile file was found in index file";
    }
    $self->ifuprofilename( $ifuprofile );
  } else {
    croak "Error in determining IFU profile file - giving up";
  }
}

=item B<ifuprofileindex>

=cut

sub ifuprofileindex {
  my $self = shift;
  if( @_ ) {
    $self->{IFUProfileIndex} = shift;
  }

  if( ! defined( $self->{IFUProfileIndex} ) ) {
    my $indexfile = $self->find_file( "index.ifuprofile" );
    my $rulesfile = $self->find_file( "rules.ifuprofile" );

    $self->{IFUProfileIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{IFUProfileIndex};
}

=item B<ifuprofilename>

=cut

sub ifuprofilename {
  my $self = shift;
  if( @_ ) {
    $self->{IFUProfile} = shift;
  }
  return $self->{IFUProfile};
}

=item B<offsetval>

Return (or set) the current offset value - no checking

  $iar = $Cal->offset;


=cut

sub offsetval {
  my $self = shift;
  if (@_) { $self->{Offset} = shift; }
  return $self->{Offset};
}


=item B<offset>

Returns the appropriate y-offset value.

=cut


sub offset {

  my $self = shift;
  if (@_) {
    return $self->offsetval(shift);
  };

  my $ok = $self->offsetindex->verify($self->offsetval,$self->thing);

  # happy ending
  return $self->offsetval if $ok;

  if (defined $ok) {
    my $offset = $self->offsetindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $offset) {
      # Nothing suitable, give up...
      croak "No suitable offset value was found in index file"
    }

    # Store the good value
    $self->offsetval($offset);

  } else {
    # All fall down....
    croak("Error in determining offset value - giving up");
  }
}



=item B<offsetindex>

Returns the index object associated with the offset values. 

=cut

sub offsetindex {
    my $self = shift;
    if (@_) { $self->{OffsetIndex} = shift; }
    
    unless (defined $self->{OffsetIndex}) {
        my $indexfile = "index.offset";
        my $rulesfile = $self->find_file("rules.offset");
        $self->{OffsetIndex} = new ORAC::Index($indexfile,$rulesfile);
    }

    return $self->{OffsetIndex}; 
}



=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>
adapted for UIST by S Todd (Dec 2001)

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
