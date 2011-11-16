package ORAC::Frame::ISAAC;

=head1 NAME

ORAC::Frame::ISAAC - ISAAC class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::ISAAC;

  $Frm = new ORAC::Frame::ISAAC("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to ISAAC. It provides a class derived from
B<ORAC::Frame::ESO>.  All the methods available to B<ORAC::Frame::ESO>
objects are available to B<ORAC::Frame::ISAAC> objects.

=cut

# A package to describe a ISAAC group object for the
# ORAC pipeline

use 5.006;
use warnings;
use Math::Trig;
use ORAC::Frame::CGS4;
use ORAC::Print;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame::ESO;
use base  qw/ORAC::Frame::ESO/;

# NDF module for mergehdr
use NDF;

# standard error module and turn on strict
use Carp;
use strict;

use vars qw/$VERSION/;
$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::ISAAC object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::ISAAC;
   $Frm = new ORAC::Frame::ISAAC("file_name");
   $Frm = new ORAC::Frame::ISAAC("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'm' prefix although these can be overriden with the
rawsuffix() and rawfixedpart() methods.

=cut

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;

# Run the base-class constructor with a hash reference defining
# additions to the class.   Do not supply user-arguments yet.
# This is because if we do run configure via the constructor
# the rawfixedpart and rawsuffix will be undefined.
   my $self = $class->SUPER::new();

# Configure the initial state---could pass these in with
# the class initialisation hash---this assumes that we know
# the hash member name.
#   $self->rawfixedpart( 'ISAAC.' );
#   $self->rawsuffix( '.fits' );
#   $self->rawformat( 'FITS' );
   $self->rawfixedpart( 'isaac' );
   $self->rawsuffix( '.sdf' );
   $self->rawformat( 'NDF' );

# ISAAC is really a single frame instrument.  So this should be
# "NDF" and we should be inheriting from UFTI
   $self->format( 'NDF' );

# If arguments are supplied then we can configure the object.
# Currently the argument will be the filename.
# If there are two args this becomes a prefix and number.
   $self->configure(@_) if @_;

   return $self;
}

=back

=head2 General Methods

=over 4

=back

=head1 SEE ALSO

L<ORAC::Frame::ESO>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
