package ORAC::Print;

=head1 NAME

ORAC::Print - ORAC output message printing

=head1 SYNOPSIS

  use ORAC::Print qw/:func/;

  orac_print("text",'magenta');
  orac_err("error text",'red');

  orac_err("error text");
  orac_print("some text");
  orac_warn("some warning");

  $prt = new ORAC::Print;
  $prt->out("Message","colour");
  $prt->err("Error message"); 
  $prt->war("warning message");
  $prt->err_col("red");
  $prt->out_col("magenta");

=head1 DESCRIPTION

This module provides commands for printing messages from ORAC
software. Commands are provided for printing error messages, warning
messages and information messages. The final output location of these
messages is controlled by the object configuration.

=cut


use 5.004;
use Carp;
use strict;
use vars qw/$VERSION $DEBUG $CURRENT @ISA @EXPORT/;
use subs qw/__curr_obj/;

$VERSION = '0.10';
$DEBUG = 0;

require Exporter;
@ISA = qw/Exporter/;
@EXPORT = qw/orac_print orac_err orac_warn/;


use IO::File;
use Term::ANSIColor;


=head1 NON-OO INTERFACE

A simplified non-object oriented interface is provided.
These routines are exported into the callers namespace by default
and are the commands that should be used by primitive writers.

=over 4

=item orac_print ( text , [colour])

Print the supplied text to the ORAC output device(s)
using the (optional) supplied colour.

If the colour is not specified the default value is used (magenta
for primtives).

=cut


sub orac_print {
  my $prt = __curr_obj;
  $prt->out(@_);
}

=item orac_warn( text, [colour])

Print the supplied text as a warning message using the supplied
colour.

=cut

sub orac_warn {
  my $prt = __curr_obj;
  $prt->war(@_);
}


=item orac_err( text, [colour])

Print the supplied text as an error message using the supplied
colour.

=cut

sub orac_err {
  my $prt = __curr_obj;
  $prt->err(@_);
}



# __curr_obj returns the current Print object or creates a new
# one if one has not been created already.

sub __curr_obj {
  my $prt = $CURRENT;
  $prt = new ORAC::Print unless defined $prt;
  return $prt;
}

=head1 OO INTERFACE

The following methods are available:

=over 4

=item new()

Constructor. The object is returned.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $prt = {};

  $prt->{OutColour} = 'magenta';
  $prt->{ErrColour} = 'red';
  $prt->{WarnColour} = 'blue';

  bless($prt, $class);

  # Store the current object
  $CURRENT = $prt;

  return $prt;

}


# Methods for accessing the 'instance' data


=item outcol(colour)

Retrieve (or set) the colour currently used for printing output
messages.

  $col = $prt->outcol;
  $prt->outcol('red');

Currently no check is made that the supplied colour is acceptable.

=cut

sub outcol {
  my $self = shift;
  if (@_) { $self->{OutColour} = shift; }
  return $self->{OutColour};
}

=item warncol(colour)

Retrieve (or set) the colour currently used for printing warning
messages.

  $col = $prt->warncol;
  $prt->warncol('red');

Currently no check is made that the supplied colour is acceptable.

=cut

sub warncol {
  my $self = shift;
  if (@_) { $self->{WarnColour} = shift; }
  return $self->{WarnColour};
}

=item errcol(colour)

Retrieve (or set) the colour currently used for printing error
messages.

  $col = $prt->errcol;
  $prt->outcol('red');

Currently no check is made that the supplied colour is acceptable.

=cut

sub errcol {
  my $self = shift;
  if (@_) { $self->{ErrColour} = shift; }
  return $self->{ErrColour};
}

# Methods that do things...

=item out(text, [col])

Print output messages.
Currently this method simply writes to standard out (STDOUT)

=cut

sub out {
  my $self = shift;
  my $text = shift;

  my $col = $self->outcol;
  if (@_) { $col = shift; }

  print STDOUT colored("$text",$col);

}

=item war(text, [col])

Print warning messages.
Currently this method simply writes to standard out (STDOUT)

=cut

sub war {
  my $self = shift;
  my $text = shift;

  my $col = $self->warncol;
  if (@_) { $col = shift; }

  print STDOUT colored("WARNING:$text",$col);

}

=item err(text, [col])

Print error messages.
Currently this method simply writes to standard error (STDERR)

=cut

sub err {
  my $self = shift;
  my $text = shift;

  my $col = $self->errcol;
  if (@_) { $col = shift; }

  print STDERR colored("ERROR:$text",$col);

}

=back

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=cut


1;

