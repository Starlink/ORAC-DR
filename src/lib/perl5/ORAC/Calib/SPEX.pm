package ORAC::Calib::SPEX;

=head1 NAME

ORAC::Calib::SPEX;

=head1 SYNOPSIS

  use ORAC::Calib::SPEX;

  $Cal = new ORAC::Calib::SPEX;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying SPEX-specific
calibration objects.  It provides a class derived from ORAC::Calib.
All the methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use 5.006;

# standard modules
use Carp;
use strict;
use warnings;

use ORAC::Calib;			# use base class
use base qw/ ORAC::Calib /;

use File::Spec;

use vars qw/ $VERSION /;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=over 4

=cut

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor.  Adds knowledge of mask.

  my $Cal = new ORAC::Calib::SPEX;

=cut

sub new {
   my $self = shift;
   my $obj = $self->SUPER::new(@_);

# Assumes we have a hash object.
   $obj->{Mask}        = undef;
   $obj->{MaskIndex}   = undef;
   $obj->{MaskNoUpdate} = 0;

   return $obj;

}


=back

=head2 Accessors

=over 4

=item B<maskname>

Return (or set) the name of the current bad-pixel mask.

  $mask = $Cal->maskname;

The C<mask()> method should be used if a test for suitability of the
mask is required.

=cut


sub maskname {
   my $self = shift;
   if (@_) { $self->{Mask} = shift unless $self->masknoupdate; }
   return $self->{Mask}; 
};


=item B<maskindex>

Return or set the index object associated with the bad-pixel mask.

  $index = $Cal->maskindex;

An index object is created automatically the first time this method
is run.

=cut

sub maskindex {

   my $self = shift;
   if (@_) { $self->{MaskIndex} = shift; }
   unless (defined $self->{MaskIndex}) {
      my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.mask" );
      my $rulesfile = $self->find_file("rules.mask");
      $self->{MaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
   };

   return $self->{MaskIndex};

};

=item B<masknoupdate>

Stops object from updating itself with more recent data.
Used when overrding the mask file from the command-line.

=cut

sub masknoupdate {

  my $self = shift;
  if (@_) { $self->{MaskNoUpdate} = shift; }
  return $self->{MaskNoUpdate};

}

=back

=head2 General Methods

=over 4

=item B<mask>

Return (or set) the name of the current mask.  If a mask is to be returned 
every effort is made to guarantee that the mask is suitable for use.

  $mask = $Cal->mask;
  $Cal->mask( $newmask );

If no suitable mask can be found from the index file (or the currently
set mask is not suitable), the INGRID C<$ORAC_DATA_CAL/bpm> is returned by
default (so long as the file does exist).  Note that a test for
suitability can not be performed since there is no corresponding index
entry for this default mask.

=cut

sub mask {

   my $self = shift;

   if (@_) {
      return $self->maskname( shift );
   };

   my $ok = $self->maskindex->verify( $self->maskname, $self->thing );

# Return the name if successful.
   return $self->maskname if $ok;

   croak ( "Override mask is not suitable!  Giving up." ) if $self->masknoupdate;

   if ( defined $ok ) {
      my $mask = $self->maskindex->choosebydt( 'ORACTIME', $self->thing );

      unless ( defined $mask ) {

# There is no suitable mask.  Default to fallback position.
# Check that the default mask exists and be careful not to set this
# as the maskname() value since it has no corresponding index entry.
        my $defmask = $self->find_file("bpm.sdf");
        if( defined( $defmask ) ) {
          $defmask =~ s/\.sdf$//;
          return $defmask;
        }

# Give up...
         croak "No suitable bad pixel mask was found in index file.";
      }

# Store the good value.
      $self->maskname( $mask );

   } else {

# All fall down....
      croak "Error in determining bad pixel mask.  Giving up.";
   }

}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie (mjc@star.rl.ac.uk)

=head1 COPYRIGHT

Copyright (C) 2004-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
