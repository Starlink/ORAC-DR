package ORAC::Frame::UKIRT;

=head1 NAME

ORAC::Frame::UKIRT - UKIRT class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::UKIRT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to UKIRT. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::UKIRT> objects.

=cut
 
# A package to describe a UKIRT group object for the
# ORAC pipeline
 
use 5.004;
use vars qw/$VERSION/;
use ORAC::Frame::NDF;
use ORAC::Constants;
 
# Let the object know that it is derived from ORAC::Frame::NDF;
use base qw/ORAC::Frame::NDF/;
 
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

 
# standard error module and turn on strict
use Carp;
use strict;
 

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 General Methods

=over 4

=item B<findgroup>

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

The group name stored in the object is automatically updated using 
this value.

=cut

sub findgroup {

  my $self = shift;

  my $hdrgrp = $self->hdr('GRPNUM');

  # Is this group name set to anything useful
  if ($hdrgrp == 0) {
    # if the group is invalid there is not a lot we can do about
    # it except for the case of certain calibration objects that
    # we know are the only members of their group (eg DARK)

#    if ($self->hdr('OBJECT') eq 'DARK') {
       $hdrgrp = $self->hdr('RUN');
#    }

  }

  $self->group($hdrgrp);

  return $hdrgrp;

}

=item B<findrecipe>

Find the recipe name. If no recipe can be found from the
'DRRECIPE' FITS keyword'QUICK_LOOK' is returned by default.

The recipe name stored in the object is automatically updated using 
this value.

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('DRRECIPE');

  # Check to see whether there is something there
  # if not try to make something up
  if ($recipe !~ /./) {
    $recipe = 'QUICK_LOOK';
  } 

  # Update
  $self->recipe($recipe);

  return $recipe;
}


=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
    

=cut

 
1;
