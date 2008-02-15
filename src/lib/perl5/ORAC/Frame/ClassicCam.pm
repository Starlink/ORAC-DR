package ORAC::Frame::ClassicCam;

=head1 NAME

ORAC::Frame::ClassicCam - Class for dealing with Magellan ClassicCam observation frames

=head1 SYNOPSIS

  use ORAC::Frame::ClassicCam;

  $Frm = new ORAC::Frame::ClassicCam("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to ClassicCam. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to B<ORAC::Frame>
objects are available to B<ORAC::Frame::ClassicCam> objects.

The class only deals with the NDF form of ClassicCam data rather than the
native FITS format (the pipeline forces a conversion as soon as the
data are located).

=cut

use 5.006;
use warnings;
use strict;
use Carp;
use ORAC::Print qw/orac_warn/;
use ORAC::Constants;

our $VERSION;

use base qw/ORAC::Frame::UKIRT/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::ClassicCam> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::ClassicCam;
   $Frm = new ORAC::Frame::ClassicCam("file_name");
   $Frm = new ORAC::Frame::ClassicCam("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'cc' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {
   my $proto = shift;
   my $class = ref( $proto ) || $proto;

# Run the base class constructor with a hash reference
# defining additions to the class.  Do not supply user-arguments
# yet. This is because if we do run configure via the constructor
# the rawfixedpart and rawsuffix will be undefined.
   my $self = $class->SUPER::new();

# Configure initial state - could pass these in with
# the class initialisation hash - this assumes that I know
# the hash member name
   $self->rawfixedpart( 'cc' );
   $self->rawsuffix( '.sdf' );
   $self->rawformat( 'NDF' );
   $self->format( 'NDF' );

# If arguments are supplied then we can configure the object.
# Currently the argument will be the filename.
# If there are two args this becomes a prefix and number.
   $self->configure( @_ ) if @_;

   return $self;
}

=back

=head2 General Methods

=over 4

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts.  A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

For ClassicCam the raw filename after pressing by cc2oracdr.csh is
of the form:

  ccYYYYMMDD_NNNNN.sdf

where the number is 0 padded.

=cut

sub file_from_bits {
   my $self = shift;

   my $prefix = shift;
   my $obsnum = shift;

# Zero pad the number.
   $obsnum = sprintf( "%05d", $obsnum );

# Temporary ClassicCam UKIRT-like form form is fixed prefix _ num suffix
   return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=item B<findgroup>

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

The group name stored in the object is automatically updated using 
this value.

=cut

sub findgroup {

   my $self = shift;

   my $amiagroup;
   my $hdrgrp;

   $hdrgrp = $self->hdr('GRPNUM');
   if ($self->hdr('GRPMEM')) {
      $amiagroup = 1;
   } elsif (!defined $self->hdr('GRPMEM')){
      $amiagroup = 1;
   } else {
      $amiagroup = 0;
   }

# Is this group name set to anything useful
  if ( !$hdrgrp || !$amiagroup ) {

# If the group is invalid there is not a lot we can do about
# it except for the case of certain calibration objects that
# we know are the only members of their group (e.g. DARK).

#    if ($self->hdr('OBJECT') eq 'DARK') {
       $hdrgrp = 0;
#    }

  }

  $self->group( $hdrgrp );

  return $hdrgrp;

}

=item B<inout>

Method to return the current input filename and the new output
filename given a suffix. The input filename is chopped at the
underscore and the suffix appended. The suffix is simply appended
if there is no underscore.

Note that this method does not set the new output name in this
object. This must still be done by the user.

Returns $in and $out in an array context:

   ($in, $out) = $Frm->inout($suffix);

Returns $out in a scalar context:

   $out = $Frm->inout($suffix);

Therefore if in=file_db and suffix=_ff then out would
become file_db_ff but if in=file_db_ff and suffix=dk then
out would be file_db_dk.

An optional second argument can be used to specify the
file number to be used. Default is for this method to process
the contents of file(1).

  ($in, $out) = $Frm->inout($suffix, 2);

will return the second file name and the name of the new output
file derived from this.

The last suffix is not removed if it consists solely of numbers.
This is to prevent truncation of raw data filenames.

=cut

=item B<mergehdr>

Dummy method.

  $frm->mergehdr();

=cut

sub mergehdr {

}

=item B<template>

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Frm->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

=cut

sub template {
   my $self = shift;
   my $template = shift;

   my $num = $self->number;

# Pad with leading zeroes for a 5-digit obsnum.
   $num = "0" x ( 5 - length( $num ) ) . $num;

# Change the first number.
   $template =~ s/_\d+_/_${num}_/;

# Update the filename.
   $self->file( $template );

}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
