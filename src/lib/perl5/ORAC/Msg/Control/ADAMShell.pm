package ORAC::Msg::Control::ADAMShell;

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
use ORAC::Constants qw/ORAC__OK/;

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

sub init { ORAC__OK }

=back

=head1 CLASS METHODS

=over 4

=item B<require_uniqid>

Returns false, indicating that the shell does not require unique
engine identifiers since each invocation will be fresh,

=cut

sub require_uniqid {
  return 0;
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
