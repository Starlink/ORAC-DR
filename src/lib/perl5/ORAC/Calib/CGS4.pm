package ORAC::Calib::CGS4;

=head1 NAME

ORAC::Calib::CGS4;

=head1 SYNOPSIS

  use ORAC::Calib::CGS4;

  $Cal = new ORAC::Calib::CGS4;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $readnoise = $Cal->readnoise;

=head1 DESCRIPTION

This module contains methods for specifying CGS4-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use strict;
use Carp;
use warnings;

use ORAC::Print;

use File::Spec;       # for catfile

use base qw/ORAC::Calib::Spectroscopy/;

use vars qw/$VERSION/;
$VERSION = '1.0';

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of extraction rows.

  my $Cal = new ORAC::Calib::CGS4;

=cut

sub new {
  my $self = shift;
  my $obj = $self->SUPER::new(@_);

  # Assumes we have a hash object
  $obj->{Engineering} = undef;
  $obj->{EngineeringIndex} = undef;

  return $obj;

}


=back

=head2 Accessors

=over 4

=item B<engineeringindex>

Return (or set) the index object associated with the engineering
parameters index file.

=cut

sub engineeringindex {
  my $self = shift;
  if( @_ ) { $self->{EngineeringIndex} = shift; }
  unless( defined( $self->{EngineeringIndex} ) ) {
    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'},
                                         "index.engineering" );
    my $rulesfile = $self->find_file( "rules.engineering" );
    croak "engineering rules file could not be located\n" unless defined $rulesfile;
    $self->{EngineeringIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{EngineeringIndex};
}

=back

=head2 General Methods

=over 4

=item B<default_mask>

Return the default mask.

=cut

sub default_mask {
  return "fpa46_long.sdf";
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
