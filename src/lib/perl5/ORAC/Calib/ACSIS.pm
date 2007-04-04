package ORAC::Calib::ACSIS;

=head1 NAME

ORAC::Calib::ACSIS;

=head1 SYNOPSIS

  use ORAC::Calib::ACSIS;

  $Cal = new ORAC::Calib::ACSIS;

=head1 DESCRIPTION

This module contains methods for specifying ACSIS-specific calibration
objects. It provides a class derived from ORAC::Calib. All the methods
available to ORAC::Calib objects are also available to
ORAC::Calib::ACSIS objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Spec;

use base qw/ ORAC::Calib /;

use vars qw/ $VERSION /;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of pointing, reference
spectrum, beam efficiency, and other ACSIS-specific calibration
information.

=cut

sub new {
  my $self = shift;
  my $obj = $self->SUPER::new( @_ );

# This assumes we have a hash object.
  $obj->{Pointing} = undef;
  $obj->{PointingIndex} = undef;
  $obj->{PointingNoUpdate} = 0;

  return $obj;
}

=back

=head2 Accessors

=over 4

=item B<pointing>

Return (or set) the most recent pointing values.

  $pointing = $Cal->pointing;

=cut

sub pointing {
  my $self = shift;

  # Handle arguments.
  return $self->pointingcache( shift ) if @_;

  if( $self->pointingnoupdate ) {
    my $cache = $self->pointingcache;
    return $cache if defined $cache;
  }

  my $pointingfile = $self->pointingindex->choosebydt( 'ORACTIME', $self->thing );
  if( ! defined( $pointingfile ) ) {
    croak "No suitable pointing value found in index file"
  }

  my $pointingref = $self->pointingindex->indexentry( $pointingfile );
  if( exists( $pointingref->{DAZ} ) &&
      exists( $pointingref->{DEL} ) ) {
    return $pointingref;
  } else {
    croak "Unable to obtain DAZ and DEL from index file entry $pointingfile\n";
  }
}

=item B<pointingcache>

Cached value of the pointing. Only used when noupdate is in effect.

=cut

sub pointingcache {
  my $self = shift;
  if( @_ ) { $self->{Pointing} = shift unless $self->pointingnoupdate; }
  return $self->{Pointing};
}

=item B<pointingnoupdate>

Stops pointing object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub pointingnoupdate {
  my $self = shift;
  if( @_ ) { $self->{PointingNoUpdate} = shift; }
  return $self->{PointingNoUpdate};
}

=item B<pointingindex>

Return (or set) the index object associated with the pointing index
file.

=cut

sub pointingindex {
  my $self = shift;
  if( @_ ) { $self->{PointingIndex} = shift; }

  if( ! defined( $self->{PointingIndex} ) ) {
    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.pointing" );
    my $rulesfile = $self->find_file( "rules.pointing" );
    if( ! defined( $rulesfile ) ) {
      croak "pointing rules file could not be located\n";
    }
    $self->{PointingIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{PointingIndex};

}

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.  All
Rights Reserved.

=cut

1;
