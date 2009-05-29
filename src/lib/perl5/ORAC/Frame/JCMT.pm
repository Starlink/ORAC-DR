package ORAC::Frame::JCMT;

=head1 NAME

ORAC::Frame::JCMT - JCMT class for dealing with observation files in
ORAC-DR.

=head1 SYNOPSIS

  use ORAC::Frame::JCMT;

  $Frm = new ORAC::Frame::JCMT( "filename" );

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to JCMT instruments. It provides a class derived from
B<ORAC::Frame::NDF>. All the methods available to B<ORAC::Frame>
objects are also available to B<ORAC::Frame::JCMT> objects.

=cut

use 5.006;
use strict;
use warnings;

use vars qw/ $VERSION /;
use ORAC::Frame::NDF;

use Carp;
use NDF;

use base qw/ ORAC::Frame::NDF /;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are available in this class in addition to those
available from B<ORAC::Frame>.

=head2 General Methods

=over 4

=item B<jcmtstate>

Return a value from either the first or last entry in the JCMT STATE
structure.

  my $value = $Frm->jcmtstate( $keyword, 'end' );

If the supplied keyword does not exist in the JCMT STATE structure,
this method returns undef. An optional second argument may be given,
and must be either 'start' or 'end'. If this second argument is not
given, then the first entry in the JCMT STATE structure will be used
to obtain the requested value.

Both arguments are case-insensitive.

=cut

sub jcmtstate {
  my $self = shift;

  my $keyword = uc( shift );
  my $which = shift;

  if( defined( $which ) && uc( $which ) eq 'END' ) {
    $which = 'END';
  } else {
    $which = 'START';
  }

  # First, check our cache.
  if( exists $self->{JCMTSTATE} ) {
    print "going to cache\n";
    return $self->{JCMTSTATE}->{$which}->{$keyword};
  }

  # Get the first and last files in the Frame object.
  my $first = $self->file( 1 );
  my $last = $self->file( $self->nfiles );

  # Open up the file, retrieve the JCMTSTATE structure, and store it
  # in our cache.
  my $status = &NDF::SAI__OK();
  err_begin($status);

  hds_open( $first, "READ", my $loc, $status);
  dat_find( $loc, "MORE", my $mloc, $status);
  dat_find( $mloc, "JCMTSTATE", my $jloc, $status);
  dat_annul( $mloc, $status);

  # find out how many extensions we have
  dat_ncomp( $jloc, my $ncomp, $status );

  # Loop over each
  for my $i (1..$ncomp) {
    dat_index( $jloc, $i, my $iloc, $status );
    dat_name( $iloc, my $name, $status );
    dat_size( $iloc, my $size, $status );
    dat_type( $iloc, my $type, $status );

    my $coderef;
    if ($type =~ /^_(DOUBLE|REAL)$/) {
      $coderef = \&dat_get0d;
    } elsif ($type eq '_INTEGER') {
      $coderef = \&dat_get0i;
    } else {
      $coderef = \&dat_get0c;
    }

    my @cell = ( 1 );
    dat_cell( $iloc, 1, @cell, my $cloc, $status );
    $coderef->( $cloc, $self->{JCMTSTATE}->{START}->{$name}, $status );
    dat_annul( $cloc, $status );

    if( uc( $first ) eq uc( $last ) ) {
      @cell = ( $size );
      dat_cell( $iloc, 1, @cell, my $cloc2, $status );
      $coderef->(  $cloc2, $self->{JCMTSTATE}->{END}->{$name}, $status );
      dat_annul( $cloc2, $status );
    }

    dat_annul( $iloc, $status );
  }

  dat_annul($jloc, $status );
  dat_annul( $loc, $status );

  if ($status != &NDF::SAI__OK()) {
    croak err_flush_to_string( "Error reading file $first:\n".$status );
  }

  # If there's more than one file in the Frame, open the last one.
  if( uc( $first ) ne uc( $last ) ) {
    hds_open( $last, "READ", my $loc, $status);
    dat_find( $loc, "MORE", my $mloc, $status);
    dat_find( $mloc, "JCMTSTATE", my $jloc, $status);
    dat_annul( $mloc, $status);

    # find out how many extensions we have
    dat_ncomp( $jloc, my $ncomp, $status );

    # Loop over each
    for my $i (1..$ncomp) {
      dat_index( $jloc, $i, my $iloc, $status );
      dat_name( $iloc, my $name, $status );
      dat_size( $iloc, my $size, $status );
      dat_type( $iloc, my $type, $status );

      my $coderef;
      if ($type =~ /^_(DOUBLE|REAL)$/) {
        $coderef = \&dat_get0d;
      } elsif ($type eq '_INTEGER') {
        $coderef = \&dat_get0i;
      } else {
        $coderef = \&dat_get0c;
      }

      my @cell = ( $size );
      dat_cell( $iloc, 1, @cell, my $cloc, $status );
      $coderef->( $cloc, $self->{JCMTSTATE}->{END}->{$name}, $status );
      dat_annul( $cloc, $status );
      dat_annul( $iloc, $status );

    }
    dat_annul($jloc, $status );
    dat_annul( $loc, $status );
  }

  if ($status != &NDF::SAI__OK()) {
    croak err_flush_to_string( "Error reading file $first:\n".$status );
  }
  err_end($status);

  return $self->{JCMTSTATE}->{$which}->{$keyword};
}

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>, L<ORAC::Frame>

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
Tim Jenness <t.jenness@jach.hawaii.edu>

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council. All
Rights Reserved.

=cut

1;
