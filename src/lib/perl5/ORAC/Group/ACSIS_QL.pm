package ORAC::Group::ACSIS_QL;

=head1 NAME

ORAC::Group::ACSIS_QL - ACSIS_QL class for dealing with observation
groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::ACSIS_QL("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that are
specific to ACSIS_QL. It provides a class derived from
B<ORAC::Group::NDF>.  All the methods available to B<ORAC::Group>
objects are available to B<ORAC::Group::ACSIS_QL> objects.

=cut

# A package to describe a ACSIS_QL group object for the ORAC pipeline

use 5.006;
use strict;
use warnings;
our $VERSION;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

use ORAC::Group::NDF;

use base qw/ ORAC::Group::NDF /;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of an B<ORAC::Group::ACSIS_QL> object. This method
takes an optional argument containing the name of the new group.
The object identifier is returned.

  $Grp = new ORAC::Group::ACSIS_QL;
  $Grp = new ORAC::Group::ACSIS_QL("group_name");

This method calls the base class constructor but initialises the group
with a file suffix if ".sdf" and a fixed part of "ga".

=cut

sub new {
  my $proto = shift;
  my $class = ref( $proto ) || $proto;

# Do not pass objects if the constructor required
# knowledge of fixedpart() and filesuffix().
  my $group = $class->SUPER::new(@_);

# Configure it.
  $group->fixedpart('ga');
  $group->filesuffix('.sdf');

# And return the new object.
  return $group;
}

=back

=head2 General Methods

=over 4

=item B<file>

=cut

sub file {
  my $self = shift;

  if( @_ ) {
    my $arg = shift;

    if( $arg =~ /^\d+$/ ) {

      my $frm = $self->frame( $self->num );
      my @subs = $frm->subs;

      my $sub = $subs[$arg - 1];
      my $file = $self->grpoutsub( $sub );
      return $file;
    } else {
      $self->{File} = $self->stripfname( $arg );
    }
  }
  return $self->{File};
}

sub grpoutsub {
  my $self = shift;

  my $sub = shift;

  my $file = $self->file;

  my $suffix = '_' . lc( $sub );

  $file .= $suffix unless $file =~ /$suffix$/;

  return $file;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;
