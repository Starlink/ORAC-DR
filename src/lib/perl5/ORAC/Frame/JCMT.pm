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
use JSA::Headers qw/ read_jcmtstate /;

use Carp;
use base qw/ ORAC::Frame::NDF /;

$VERSION = '1.01';

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
    return $self->{JCMTSTATE}->{$which}->{$keyword};
  }

  # Get the first and last files in the Frame object.
  my $first = $self->file( 1 );
  my $last = $self->file( $self->nfiles );

  # Reference to hash bucket in cache to simplify
  # references in code later on
  my $startref = $self->{JCMTSTATE}->{START} = {};
  my $endref = $self->{JCMTSTATE}->{END} = {};

  # if we have a single file read the start and end
  # read the start and end into the cache regardless
  # of what was requested in order to minimize file opening.
  if ($first eq $last ) {
    my %values = read_jcmtstate( $first, [qw/ start end /] );
    for my $key ( keys %values ) {
      $startref->{$key} = $values{$key}->[0];
      $endref->{$key} = $values{$key}->[1];
    }
  } else {
    my %values = read_jcmtstate( $first, 'start' );
    %$startref = %values;
    %values = read_jcmtstate( $last, 'end' );
    %$endref = %values;

  }
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
