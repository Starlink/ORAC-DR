package ORAC::Frame::IRIS2;

=head1 NAME

ORAC::Frame::IRIS2 - Class for dealing with IRIS2 observation frames

=head1 SYNOPSIS

  use ORAC::Frame::IRIS2;

  $Frm = new ORAC::Frame::IRIS2("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to IRIS2. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available to
B<ORAC::Frame::IRIS2> objects.

The class only deals with the NDF form of IRIS2 data rather than the
native FITS format (the pipeline forces a conversion as soon as the
data are located).

=cut

use 5.006;
use warnings;
use strict;
use Carp;

our $VERSION;

use base qw/ORAC::Frame::NDF/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

use ORAC::Constants;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::UFTI> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::UFTI;
   $Frm = new ORAC::Frame::UFTI("file_name");
   $Frm = new ORAC::Frame::UFTI("UT","number");

The constructor hard-wires the '.fits' rawsuffix and the
'f' prefix although these can be overriden with the 
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
  $self->rawfixedpart('');
  $self->rawsuffix('.fits');
  $self->rawformat('FITS');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;

}

=back

=head2 General Methods

=over 4


=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Should be run after a header is set. Currently the hdr()
method calls this whenever it is updated.

Calculates ORACUT and ORACTIME

ORACUT is the UT date in YYYYMMDD format.
ORACTIME is the time of the observation in YYYYMMDD.fraction
format.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME - same format as SCUBA uses

  # First get the time of day
  my $time = $self->hdr('UTSTART');
  if (defined $time) {
    # Need to split on :
    my ($h,$m,$s) = split(/:/,$time);
    $time = $h + $m/60 + $s/3600;
  } else {
    $time = 0;
  }

  # Now get the UT date
  my $date = $self->hdr('UTDATE');
  if (defined $date) {
    my ($y,$m,$d) = split(/:/, $date);
    $date = $y . '0'x (2-length($m)) . $m . '0'x (2-length($d)) . $d;
  } else {
    $date = 0;
  }

  my $ut = $date + ( $time / 24.0 );

  # Update the header
  $self->hdr('ORACTIME', $ut);
  $self->hdr('ORACUT',   $date);

  $new{'ORACTIME'} = $ut;
  $new{ORACUT} = $date;

  return %new;
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

IRIS2 file name convention is

  DDmmmNNNN.fits

where DD is the day number, mmm is the first 3 letters of the
month and NNNN is the zero-padded observation number. e.g

  23mar0001.fits

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes - 5(!) digit obsnum
  # Could use sprintf
  my $padnum = '0'x(4-length($obsnum)) . $obsnum;

  my $month = substr($prefix, 4, 2);
  my $day   = substr($prefix, 6, 2);

  my @months = qw/ jan feb mar apr may jun jul aug sep oct nov dec/;
  $prefix = $day . $months[$month-1];

  # UFTI naming
  return $prefix . $padnum . $self->rawsuffix;
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

  my $hdrgrp = $self->hdr('GRPNUM');
  my $amiagroup;


  if ($self->hdr('GRPMEM')) {
    $amiagroup = 1;
  } elsif (!defined $self->hdr('GRPMEM')){
    $amiagroup = 1;
  } else {
    $amiagroup = 0;
  }

  # Is this group name set to anything useful
  if (!$hdrgrp || !$amiagroup ) {
    # if the group is invalid there is not a lot we can do about
    # it except for the case of certain calibration objects that
    # we know are the only members of their group (eg DARK)

#    if ($self->hdr('OBJECT') eq 'DARK') {
       $hdrgrp = 0;
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
  if (!defined($recipe) or $recipe !~ /./) {
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

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
