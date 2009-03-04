package ORAC::Frame::IRCAM;

=head1 NAME

ORAC::Frame::IRCAM - IRCAM class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::IRCAM;

  $Frm = new ORAC::Frame::IRCAM("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to IRCAM. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to
B<ORAC::Frame::UKIRT> objects are available to B<ORAC::Frame::IRCAM>
objects. Some additional methods are supplied.

=cut

# A package to describe a UFTI group object for the
# ORAC pipeline

# standard error module and turn on strict
use Carp;
use strict;

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame::UKIRT;
use base qw/ORAC::Frame::UKIRT/;
 
$VERSION = '1.0';

# Create an alias for file_from_bits().
*pattern_from_bits = \&file_from_bits;

# For reading the header
use NDF;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::UKIRT>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::IRCAM> object.
This method also takes optional arguments:
if one argument is supplied it is assumed to be the name
of the raw file associated with the observation. If two arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::IRCAM;
   $Frm = new ORAC::Frame::IRCAM("file_name");
   $Frm = new ORAC::Frame::IRCAM("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'ro' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class.
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name.
  $self->rawfixedpart('ro');
  $self->rawsuffix('.sdf');
  $self->rawformat('NDF');
  $self->format('NDF');
 
  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number.
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

pattern_from_bits() is currently an alias for file_from_bits(),
and the two may be used interchangably for IRCAM.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

# Remove the century as these filenames feature the `millenium bug' to
# leave YYMMDD.
  $prefix = substr( $prefix, -6, 6 );

    # IRCAM form is  FIXED PREFIX _ NUM SUFFIX
  return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=item B<flag_from_bits>

Determine the name of the flag file given the variable component
parts. A prefix (usually UT) and observation number should be
supplied.

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
IRCAM.

=cut



sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;
  
  # flag files for IRCAM of the type .42_ok
  
  my $flag = ".".$obsnum."_ok";

}



=back

=head1 REQUIREMENTS

Currently this module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2008 Science & Technology Facilities Council
Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
