package ORAC::Frame::OCGS4;

=head1 NAME

ORAC::Frame::OCGS4 - CGS4 class for dealing with old style observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::OCGS4;

  $Frm = new ORAC::Frame::OCGS4("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to old style CGS4. It provides a class derived from
B<ORAC::Frame::CGS4>. All the methods available to B<ORAC::Frame::CGS4>
objects are available to B<ORAC::Frame::OCGS4> objects. Some additional
methods are supplied.

=cut

# A package to describe a UKIRT group object for the
# ORAC pipeline

use 5.006;
use warnings;
use Carp;
use strict;

use ORAC::Frame::CGS4;
use ORAC::Print;

# Let the object know that it is derived from ORAC::Frame;
use base  qw/ORAC::Frame::CGS4/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame::UKIRT.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::UKIRT object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::OCGS4;
   $Frm = new ORAC::Frame::OCGS4("file_name");
   $Frm = new ORAC::Frame::OCGS4("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'c' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;
  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('o');
  $self->rawsuffix('.sdf');
  $self->rawformat('UKIRTIO');
  $self->format('HDS');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;
}

=back

=head2 General Methods

=over 4

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

For OCGS4 the raw filename is of the form:

  oYYMMDD_N.sdf

where the number is NOT 0 padded.

We get passed the prefix as YYYYMMDD, so have to strip off the 1st 2
digits.

pattern_from_bits() is currently an alias for file_from_bits(),
and the two can be used interchangably for the OCGS4 subclass.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # Don't Zero pad the number
  # $obsnum = sprintf("%05d", $obsnum);

  # Chop down the prefix
  $prefix = substr $prefix, 2;

  # CGS4 form is  FIXED PREFIX _ NUM SUFFIX
  return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=back

=head1 SEE ALSO

L<ORAC::Frame::CGS4>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Paul Hirst E<lt>p.hirst@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut
