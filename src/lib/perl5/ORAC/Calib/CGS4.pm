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
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying CGS4-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use ORAC::Calib;			# use base class

use base qw/ORAC::Calib/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);
# @ORAC::Calib::CGS4::ISA = qw/ORAC::Calib/; # set up inheritance

# standard error module and turn on strict
use Carp;
use strict;

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
  $obj->{RowName}     = undef;
  $obj->{RowIndex}    = undef;

  return $obj;

}


=back

=head2 Accessors

=over 4

=item B<mask>

Return (or set) the name of the bad pixel mask

  $mask = $Cal->mask;

For CGS4 this is set to C<$ORAC_DATA_CAL/fpa46_long> by default

=cut


sub mask {
  my $self = shift;
  if (@_) { $self->{Mask} = shift; }

  unless (defined $self->{Mask}) {
    $self->{Mask} = $ENV{ORAC_DATA_CAL}."/fpa46_long";
  };

  return $self->{Mask}; 
};

=item B<rowname>

Returns the name of the key to use in the index file to retrieve
the currently accepted positions of the positive and negative row.
The value should be compared with the current frame header in order
to guarantee its suitability. The name is usually the name of the
observation frame used to calculate the row positions.

Can be used to set or retrieve the name.

  $name = $Cal->rowname;
  $Cal->rowname($name);

=cut

sub rowname {
  my $self = shift;
  if (@_) { $self->{RowName} = shift; }
  return $self->{RowName};
}

=item B<rowindex>

The ORAC::Index object associated with the extraction row.

=cut

sub rowindex {
  my $self = shift;

  if (@_) { $self->{RowIndex} = shift; }

  unless (defined $self->{RowIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.row";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.row";
    $self->{RowIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{RowIndex}; 

}

=back

=head2 General Methods

=over 4

=item B<rows>

Returns the relevant extraction rows to the caller by comparing
the index entries with the current frame. Suitable
values will be found or the method will abort.

Returns two numbers, the position of the positive row and the position
of the negative.

  my ($posrow, $negrow) = $Cal->rows;

Can not be used to set the name of the index key. Use the C<rowname>
method for that.

=cut

sub rows {
  my $self = shift;

  # Compare the current value with the index entry
  my $rowname = $self->rowname;
  my $ok = $self->rowindex->verify( $rowname, $self->thing );
  
  # If this was not okay we need to search the index
  unless ($ok) {

    $rowname = $self->rowindex->choosebydt('ORACTIME', $self->thing);
    croak "No suitable row could be found in index file"
      unless defined $rowname;

    # Store it
    $self->rowname( $rowname );
  }

  # Retrieve the POSROW and NEGROW from the index
  my $entry = $self->rowindex->indexentry($rowname);

  # Sanity check
  croak "POSROW could not be found in index entry $rowname\n"
    unless (exists $entry->{POSROW});
  croak "NEGROW could not be found in index entry $rowname\n"
    unless (exists $entry->{NEGROW});

  return ( $entry->{POSROW}, $entry->{NEGROW} );
}


=back

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
