package ORAC::Frame::MichTemp;

=head1 NAME

ORAC::Frame::MichTemp - class for dealing with temporary Michelle observation files 

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::UKIRT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to Michelle. The input files must be NDFs containing a single
data array (unlike the final Michelle data format).  It provides a
class derived from B<ORAC::Frame::UKIRT>.  All the methods available to
B<ORAC::Frame::UKIRT> objects are available to B<ORAC::Frame::MichTemp>
objects.

=cut
 
# A package to describe a MichTemp group object for the
# ORAC pipeline
 
use 5.004;
use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;
 
# Let the object know that it is derived from ORAC::Frame;
use base qw/ORAC::Frame::UKIRT/;
 
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);
 
# standard error module and turn on strict
use Carp;
use strict;
 
# For reading the header
use NDF;



=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::MichTemp> object.  This
method also takes optional arguments: if 1 argument is supplied it is
assumed to be the name of the raw file associated with the
observation. If 2 arguments are supplied they are assumed to be the
raw file prefix and observation number. In any case, all arguments are
passed to the configure() method which is run in addition to new()
when arguments are supplied.  The object identifier is returned.

   $Frm = new ORAC::Frame::MichTemp;
   $Frm = new ORAC::Frame::MichTemp("file_name");
   $Frm = new ORAC::Frame::MichTemp("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'M' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $frame = {};  # Anon hash

  $frame->{RawName} = undef;
  $frame->{Header} = {};
  $frame->{Group} = undef;
  $frame->{Files} = [];
  $frame->{Recipe} = undef;
  $frame->{RawSuffix} = ".sdf";
  $frame->{RawFixedPart} = 'M'; 
  $frame->{UHeader} = {};
  $frame->{NoKeepArr} = [];
  $frame->{Intermediates} = [];

  bless($frame, $class);

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  # This could be extended to include a reference to a hash holding the
  # header info but this may well compromise the object since
  # the best way to generate the header (including extensions) is to use the
  # readhdr method.

  if (@_) { 
    $frame->configure(@_);
  }

  return $frame;

}


=head2 General Methods

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

The number is zero-padded to 5 characters.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes - 5(!) digit obsnum
  my $padnum = '0'x(5-length($obsnum)) . $obsnum;

  # UFTI naming
  return $self->rawfixedpart . $prefix . '_' . $padnum . $self->rawsuffix;
}


=item B<findrecipe>

Find the recipe name. If a recipe name can not be found in the
header (searching for 'RECIPE') the 'ARRAY_ENG' recipe is assumed.

The recipe name stored in the object is automatically updated using 
this value.

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('RECIPE');

  # Check to see whether there is something there
  # if not try to make something up
  if ($recipe !~ /./) {
    $recipe = 'ARRAY_ENG';
  } 
  $self->recipe($recipe);

  return $recipe;

}


=item B<template>

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Frm->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

This method replaces the number in the supplied string with 
the current frame number (padded with zeroes up to a length
of 5).

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $num = $self->number;
  # pad with leading zeroes - 5(!) digit obsnum
  my $num = '0'x(5-length($num)) . $num;

  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($template);

}

=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=over 4

=item stripfname

Method to strip file extensions from the filename string. This method
is called by the file() method. For UKIRT we strip all extensions of the
form ".sdf", ".sdf.gz" and ".sdf.Z" since Starlink tasks do not require
the extension when accessing the file name.

=cut

sub stripfname {

  my $self = shift;

  my $name = shift;

  # Strip everything after the first dot

  $name =~ s/\.sdf$//;

  
  return $name;
}


=back

=head1 REQUIREMENTS

Currently this module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Group::UKIRT>

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
    

=cut

 
1;
