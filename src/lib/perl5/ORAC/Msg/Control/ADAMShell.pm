package ORAC::Msg::Control::Shell;

=head1 NAME

ADAMShell - Stub interface for control of ADAM Shell processes

=head1 SYNOPSIS

  use ORAC::Msg::Control::Shell;

  $ctrl = new ORAC::Msg::Control::Shell;
  $ctrl->timeout(600);


=head1 DESCRIPTION

This is currently a stub interface that does nothing except
provide empty methods. This is provided so that invocation
of ADAM tasks via a system() interface can match the standard
ORAC-DR messaging environment.

=cut

use strict;


=head2 Constructors

The following constructors are provided:

=over 4

=item B<new>

Create a new instance of C<ORAC::Inst>.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $messys = {
	       };

  bless($messys, $class);

  return $messys;
}


=head2 Accessor Methods

None of these currently do anything at all
apart from return something plausible.

=over 4

=item B<messages>

=cut

sub messages { 0 };

=item B<errors>

=cut

sub errors { 0 };

=item B<timeout>

=cut

sub timeout { 600 };

=item B<stdin>

=cut

sub stdout { \*STDOUT };

=item B<stderr>

=cut

sub stderr { \*STDERR };

=item B<paramrep>

=cut

sub paramrep { sub {}; };

=back

=head2 General Methods

=over 4

=item B<init>

=cut

sub init { }

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
