package ORAC::Event;

# ---------------------------------------------------------------------------

#+ 
#  Name:
#    ORAC::Event

#  Purposes:
#    Handles Tk events for ORAC-DR

#  Language:
#    Perl module

#  Description:
#    This module contains the routines called from oracdr, Xoracdr and
#    associated classes to manipulate a hash table of Tk references. The
#    class wraps Tk::update and Tk::MainLoop and allows the existance
#    of a GUI to be fairly transparent to ORAC-DR.

#  Authors:
#    Alasdair Allan (aa@astro.ex.ac.uk)
#     {enter_new_authors_here}

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2001 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# ---------------------------------------------------------------------------

use strict;          # smack! Don't do it again!
use warnings;
use Carp;            # Transfer the blame to someone else

# P O D  D O C U M E N T A T I O N ------------------------------------------

=head1 NAME

ORAC::Event - handles Tk events in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Event;

  ORAC::Event->register(%hash);
  ORAC::Event->update($key);
  ORAC::Event->query($key);
  ORAC::Event->mainloop($key);
  ORAC::Event->unregister($key);
  ORAC::Event->destroy($key);

=head1 DESCRIPTION

This module contains the routines called from oracdr, Xoracdr and
associated classes to manipulate a hash table of Tk references. The
class wraps Tk::update and Tk::MainLoop and allows the existance
of a GUI to be fairly transparent to ORAC-DR as updates, and other
such actions on a widget, are only called if the widget is defined.

=head1 REVISION

$Id$

=head1 AUTHORS

Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research Council.
All Rights Reserved.

=cut

# L O A D  M O D U L E S --------------------------------------------------- 

#
#  ORAC modules
#
use ORAC::Error qw/ :try /;

#
# General modules
#
use Tk; 

#
# Routines for export
#
require Exporter;
use vars qw/$VERSION @EXPORT @ISA /;

@ISA = qw/Exporter/;
@EXPORT = qw/register update mainloop unregister/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# 
# File globals
#
my ( %hash );

# M E T H O D S  -----------------------------------------------------------

=head1 METHODS

The methods are available:

=over 4

=item B<register>

This method allows a Tk reference to be registered in the hash table, e.g.

   ORAC::Event->register("Tk"=>$MW);

where in this case $MW is the reference to the Tk::MainWindow widget.

=cut

sub register {

   # Read the argument list
   my $self = shift;
   %hash = (%hash, @_);

}

=item B<update>

This method calls Tk::update on a required widget

   ORAC::Event->update($key);

where $key is the key to widget entry in the hash table

=cut

sub update {

   # Read the argument list
   my $self = shift;
   my ( $key ) = @_;

   my ( $error );

   # Pre-flush the error stack
   $error = ORAC::Error->prior;
   ORAC::Error->flush if defined $error;
   $error->throw if defined $error;

   # Call Tk::update on the widget
   $hash{$key}->update if defined $hash{$key};

   # Post-flush the error stack
   $error = ORAC::Error->prior;
   ORAC::Error->flush if defined $error;
   $error->throw if defined $error;
}

=item B<query>

This method returns a reference to a required Tk widget

   ORAC::Event->query($key);

where $key is the key to the widget entry in the hash table

=cut

sub query {

   # Read the argument list
   my $self = shift;
   my ( $key ) = @_;

   return $hash{$key} if exists $hash{$key} and defined $hash{$key};
   return; # No match
}

=item B<mainloop>

This method wraps Tk::MainLoop

   ORAC::Event->mainloop($key);

=cut

sub mainloop {

   # Read the argument list
   my $self = shift;
   my ( $key ) = @_;

   MainLoop() if exists $hash{$key} and defined $hash{$key};
}

=item B<unregister>

This method allows a Tk reference to be un-registered from the hash table

   ORAC::Event->unregister($key);

where $key is the key to the widget entry in the hash table.

=cut

sub unregister {

   # Read the argument list
   my $self = shift;
   my ( $key ) = @_;

   delete $hash{$key} if exists $hash{$key};
}

=item B<destroy>

This method wraps the Tk::destroy method, called from orac_exit_abnormally
we try and clean up after ourselves by killing the main window

   ORAC::Event->destroy($key);

where $key is the key to the widget entry in the hash table.

=cut

sub destroy {

   # Read the argument list
   my $self = shift;
   my ( $key ) = @_;

   $hash{$key}->destroy() if exists $hash{$key} and defined $hash{$key};
}

#----------------------------------------------------------------------------

=back

=head1 LICENCE

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
