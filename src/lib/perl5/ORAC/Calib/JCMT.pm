package ORAC::Calib::JCMT;

=head1 NAME

ORAC::Calib::JCMT;

=head1 SYNOPSIS

  use ORAC::Calib::JCMT;

  $Cal = new ORAC::Calib::JCMT;

=head1 DESCRIPTION

This module contains methods for specifying JCMT-specific calibration
objects. It provides a class derived from ORAC::Calib. All the methods
available to ORAC::Calib objects are also available to
ORAC::Calib::JCMT objects.

It is expected that this module will be subclassed with instrument specific
variations.

=cut

use Carp;
use warnings;
use strict;

use File::Spec;

use base qw/ ORAC::Calib /;

use vars qw/ $VERSION /;
$VERSION = '1.0';


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
  $obj->{QAParams} = undef;
  $obj->{QAParamsIndex} = undef;
  $obj->{QAParamsNoUpdate} = 0;

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

=item B<qaparams>

Return or set the filename for QA parameters.

  my $qaparams = $Cal->qaparams;

=cut

sub qaparams {
  my $self = shift;

  # Handle arguments.
  return $self->qaparamscache( shift ) if @_;

  if( $self->qaparamsnoupdate ) {
    my $cache = $self->qaparamscache;
    return $cache if defined $cache;
  }

  my $qaparamsfile = $self->qaparamsindex->choosebydt( 'ORACTIME', $self->thing );
  if( ! defined( $qaparamsfile ) ) {
    croak "No suitable QA parameters file found in index file"
  }

  return $self->find_file( $qaparamsfile );

}

=item B<qaparamscache>

Cached value for the QA parameters file. Only used when noupdate is in
effect.

=cut

sub qaparamscache {
  my $self = shift;
  if( @_ ) { $self->{QAParams} = shift unless $self->qaparamsnoupdate; }
  return $self->{QAParams};
}

=item B<qaparamsnoupdate>

Stops QA params object from updating itself.

Used when using a command-line override to the pipeline.

=cut

sub qaparamsnoupdate {
  my $self = shift;
  if( @_ ) { $self->{QAParamsNoUpdate} = shift; }
  return $self->{QAParamsNoUpdate};
}

=item B<qaparamsindex>

Return or set the index object associated with the QA parameters index
file.

=cut

sub qaparamsindex {
  my $self = shift;
  if( @_ ) { $self->{QAParamsIndex} = shift; }

  if( ! defined( $self->{QAParamsIndex} ) ) {
    my $indexfile = $self->find_file( "index.qaparams" );
    if( ! defined( $indexfile ) ) {
      croak "QA parameters index file could not be located\n";
    }
    my $rulesfile = $self->find_file( "rules.qaparams" );
    if( ! defined( $rulesfile ) ) {
      croak "QA parameters rules file could not be located\n";
    }
    $self->{QAParamsIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{QAParamsIndex};
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Science and Technology Facilities Council.
All Rights Reserved.

=cut

1;
