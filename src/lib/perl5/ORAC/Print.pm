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
  orac_throw("error text");

  $value = orac_read("Prompt");

  $prt = new ORAC::Print;
  $prt->out("Message","colour");
  $prt->err("Error message"); 
  $prt->war("warning message");
  $prt->errcol("red");
  $prt->outcol("magenta");
  $prt->errbeep(1);

  tie *HANDLE, 'ORAC::Print', $ptr;

=head1 DESCRIPTION

This module provides commands for printing messages from ORAC
software. Commands are provided for printing error messages, warning
messages and information messages. The final output location of these
messages is controlled by the object configuration.

If the C<ORAC::Print::TKMW> variable is set, it is assumed that this
is the Tk object referring to the MainWindow, and the
C<Tk-E<gt>update()> method is run whenever the C<orac_*> commands are
executed via the method in the ORAC::Event class.  This can be used to 
keep a Tk log window updating even though no X-events are being processed.

A simplified interface to Term::ReadLine is provided for use with
the orac_read command. This can only be used on STDIN/STDOUT and
is not object-oriented.

=cut


use 5.004;
use warnings;
use strict;
use vars qw/$VERSION $DEBUG $CURRENT @ISA @EXPORT $RDHDL/;
use subs qw/__curr_obj/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

$DEBUG = 0;

require Exporter;
@ISA = qw/Exporter/;
@EXPORT = qw/orac_print orac_err orac_warn orac_debug orac_read orac_throw orac_carp
	     orac_printp orac_print_prefix orac_warnp orac_errp /;

# Create a Term::ReadLine handle
# For read on STDIN and output on STDOUT
# Create one handle for the process. Note this can be overridden
# externally
$RDHDL = undef;

use ORAC::Error qw/:try/;
use ORAC::Constants qw/:status/;
use ORAC::Event;

use IO::File;
use IO::Tee;
use Term::ANSIColor;
use Term::ReadLine;

# Non-OO interface globals
my $PREFIX;

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

=item orac_carp( text, callers, [colour])

Prints the supplied text as a warning message and appends the line number
and name of the parent primitive. This information is obtained from the
standard $_PRIM_CALLERS_ variable available to each primitive.

=cut

sub orac_carp {
  my $prt = __curr_obj;
  $prt->carp(@_);
}

=item orac_err( text, [colour])

Print the supplied text as an error message using the supplied
colour.

=cut

sub orac_err {
  my $prt = __curr_obj;
  $prt->err(@_);
}

=item orac_throw( text, [colour])

Identical to C<orac_err> except that an exception is thrown (see
C<ORAC::Error>) of type C<ORAC::Error::FatalError> immediately after
the text message has been printed.

=cut

sub orac_throw {
  my $prt = __curr_obj;
  $prt->throw(@_);
}

=item orac_debug( text)

Print the supplied text as a debug message using the supplied
colour.

=cut

sub orac_debug {
  my $prt = __curr_obj;
  $prt->debug(@_);
}

=item orac_read(prompt)

Read a value from standard input. This is simply a layer
on top of Term::ReadLine.

  $value = orac_read($prompt);

There is no Object-oriented version of this routine. It always
uses STDIN for input and STDOUT for output.

=cut

sub orac_read {
  my $prompt = '';
  $prompt = shift if @_;

  # Retrieve the readline object
  # Creating it if necessary - this fails if we are not attached
  # to a tty (could check for that myself).
  $RDHDL = new Term::ReadLine 'orac_read'
    unless defined $RDHDL;

  # If TKMW is defined set tkrunning
  $RDHDL->tkRunning(1) if ORAC::Event->query("Tk");

  return $RDHDL->readline($prompt);
}

=item B<orac_print_prefix>

Set the prefix to be used by C<orac_print> in all output.

  orac_prefix( "ORAC-DR says:" );

=cut

sub orac_print_prefix {
  $PREFIX = shift;
}

=item B<orac_printp>

As for C<orac_print> but includes the prefix that has been specified
by using C<orac_print_prefix>.

 orac_printp( $text, $color );

=cut

sub orac_printp {
  my $prt = __curr_obj;
  my $current = $prt->outpre;
  $prt->outpre( $PREFIX );
  orac_print( @_ );
  $prt->outpre( $current );
}

=item B<orac_warnp>

As for C<orac_warn> but includes the prefix that has been specified
by using C<orac_print_prefix>.

 orac_warnp( $text, $color );

=cut

sub orac_warnp {
  my $prt = __curr_obj;
  my $current = $prt->warpre;
  $prt->warpre( $PREFIX );
  orac_warn( @_ );
  $prt->warpre( $current );
}

=item B<orac_errp>

As for C<orac_err> but includes the prefix that has been specified
by using C<orac_print_prefix>.

 orac_errp( $text, $color );

=cut

sub orac_errp {
  my $prt = __curr_obj;
  my $current = $prt->errpre;
  $prt->errpre( $PREFIX );
  orac_err( @_ );
  $prt->errpre( $current );
}


# __curr_obj returns the current Print object or creates a new
# one if one has not been created already.

sub __curr_obj {
  my $prt = $CURRENT;
  $prt = new ORAC::Print unless defined $prt;
  return $prt;
}

=back

=head1 OO INTERFACE

The following methods are available:

=head2 Constructors

=over 4

=item new()

Object constructor. The object is returned.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $prt = {};

  $prt->{OutColour} = 'magenta';
  $prt->{ErrColour} = 'red';
  $prt->{WarnColour} = 'cyan';
  $prt->{Debug}  = 0;           # Turns on/off debug messages
  $prt->{DebugHdl} = undef;        # Debug file handle (IO object)
  $prt->{OutHdl}   = undef;        # orac_print file handles
  $prt->{ErrHdl}   = undef;        # List of error file handles
  $prt->{WarHdl}   = undef;        # List of warning file handles
  $prt->{Prefix}   = undef;        # Prefix string
  $prt->{OutPre}   = undef;        # Output prefix
  $prt->{WarPre}   = 'Warning:';   # Prefix for warning messages
  $prt->{ErrPre}   = 'Error:';     # Prefix for error messages
  $prt->{ErrBeep}  = 0;            # Beep with error messages

  bless($prt, $class);

  # Store the current object
  $CURRENT = $prt;

  return $prt;

}


=back

=head2 Instance Methods

=over 4

=item debugmsg

Turns debugging messages on or off. Default is off.

=cut

sub debugmsg {
  my $self = shift;
  if (@_) { $self->{Debug} = shift; }
  return $self->{Debug};
}


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

=item prefix

String that is prepended to all messages printed by this class.
Default is to have no prefix.

  $prefix = $prt->prefix;
  $prt->prefix('Obs52');

=cut

sub prefix {
  my $self = shift;
  if (@_) { $self->{Prefix} = shift; }
  return $self->{Prefix};
}

=item outpre

Prefix that is prepended to all strings printed with the
out() method. Default is to have no prefix.

  $pre = $prt->outpre;
  $prt->outpre('ORAC says:');

=cut

sub outpre {
  my $self = shift;
  if (@_) { $self->{OutPre} = shift; }
  return $self->{OutPre};
}

=item warpre

Prefix that is prepended to all strings printed with the
out() method. Default is to have the string 'Warning:' prepended.

  $pre = $prt->warpre;
  $prt->warpre('ORAC Warning:');

=cut

sub warpre {
  my $self = shift;
  if (@_) { $self->{WarPre} = shift; }
  return $self->{WarPre};
}

=item errpre

Prefix that is prepended to all strings printed with the
out() method. Default is to have the string 'Error:' prepended.

  $pre = $prt->errpre;
  $prt->errpre('ORAC Error:');

=cut

sub errpre {
  my $self = shift;
  if (@_) { $self->{ErrPre} = shift; }
  return $self->{ErrPre};
}


=item outhdl

Output file handle(s). These are the filehandles that are used
to send all output messages. Multiple filehandles can be supplied.
Returns an IO::Tee object that can be used as a single filehandle.

  $Prt->outhdl(\*STDOUT, $fh);

  $fh = $Prt->outhdl;

Default is to use STDOUT.

=cut

sub outhdl {
  my $self = shift;

  # Read any args and redefine IO object
  $self->{OutHdl} = new IO::Tee(@_) if @_;

  # Set up default value
  $self->{OutHdl} = new IO::Tee(\*STDOUT)
    unless defined $self->{OutHdl};

  return $self->{OutHdl};

}

=item warhdl

Warning output file handle(s). These are the filehandles that are used
to print all warning messages. Multiple filehandles can be supplied.
Returns an IO::Tee object that can be used as a single filehandle.

  $Prt->warhdl(\*STDOUT, $fh);

  $fh = $Prt->warhdl;

Default is to use STDOUT.

=cut

sub warhdl {
  my $self = shift;

  if(!defined(@_)) { return; }

  # Read any args and redefine IO object
  $self->{WarHdl} = new IO::Tee(@_) if @_;

  # Set up default value
  $self->{WarHdl} = new IO::Tee(\*STDOUT)
    unless defined $self->{WarHdl};

  return $self->{WarHdl};

}


=item errhdl

Error output file handle(s). These are the filehandles that are used
to print all error messages. Multiple filehandles can be supplied.
Returns an IO::Tee object that can be used as a single filehandle.

  $Prt->errhdl(\*STDERR, $fh);

  $fh = $Prt->errhdl;

Default is to use STDERR.

=cut

sub errhdl {
  my $self = shift;

  # Read any args and redefine IO object
  $self->{ErrHdl} = new IO::Tee(@_) if @_;

  # Set up default value
  $self->{ErrHdl} = new IO::Tee(\*STDERR)
    unless defined $self->{ErrHdl};

  return $self->{ErrHdl};

}

=item B<errbeep>

Specifies whether the terminal is to beep when an error
message is printed. Default is not to beep (false).

  $dobeep = $Prt->errbeep;

=cut

sub errbeep {
  my $self = shift;
  if (@_) { $self->{ErrBeep} = shift;}
  return $self->{ErrBeep};
}

=item debughdl

This specifies the debug file handle. Defaults to STDERR if not 
defined. Returns an IO::Tee object that can be used as a single
filehandle.

=cut

sub debughdl {
  my $self = shift;
  # Read any args and redefine IO object
  $self->{DebugHdl} = new IO::Tee(@_) if @_;

  # Set up default value
  $self->{DebugHdl} = new IO::Tee(\*STDERR)
    unless defined $self->{DebugHdl};

  return $self->{DebugHdl};
}
 
# Methods that do things...

=back

=head2 Methods

=over 4

=item out(text, [col])

Print output messages.
By default messages are written to STDOUT. This can be overridden with
the outhdl() method.

=cut

sub out {
  my $self = shift;
  return unless @_; # Return if no second argument
  my $text = shift;

  my $col = $self->outcol;
  if (@_) { $col = shift; }

  my $fh = $self->outhdl;
  return unless defined $fh;

  my $prefix = $self->prefix;
  $prefix = '' unless defined $prefix;
  my $outpre = $self->outpre;
  $outpre = '' unless defined $outpre;

  print $fh colored($prefix . $outpre . $text ,$col);
  
  tk_update();
  
}

=item war(text, [col])

Print warning messages.
Default is to print warnings to STDOUT. This can be overriden with
the warhdl() method.

=cut

sub war {
  my $self = shift;
  return unless @_; # Return if nothing to print
  my $text = shift;

  my $col = $self->warncol;
  if (@_) { my $thiscol = shift;  $col = $thiscol if defined $thiscol; }

  my $fh = $self->warhdl;
  return unless defined $fh;

  my $prefix = $self->prefix;
  $prefix = '' unless defined $prefix;
  my $warpre = $self->warpre;
  $warpre = '' unless defined $warpre;

  print $fh colored($prefix . $warpre .$text,$col);

  tk_update();
  
}

=item carp(text, callers, [col])

=item orac_carp( text, callers, [colour])

Prints the supplied text as a warning message and appends the line number
and name of the parent primitive. This information is obtained from the
standard $_PRIM_CALLERS_ variable available to each primitive.

=cut

sub carp {
  my $self = shift;
  my $text = shift;
  my $callers = shift;
  my $col = shift;

  # add additional text
  if (defined $callers) {
    my $parent = $callers->[-1];
    $text .= " at ". $parent->[0] . " line " . $parent->[1] ."\n";
  }
  $self->war( $text, $col );
}

=item err(text, [col])

Print error messages.
Default is to use STDERR. This can be overriden with the errhdl()
method.

=cut

sub err {
  my $self = shift;
  return unless @_; # Return if nothing to print
  my $text = shift;

  my $col = $self->errcol;
  if (@_) { $col = shift; }

  my $fh = $self->errhdl;
  return unless defined $fh;

  my $prefix = $self->prefix;
  $prefix = '' unless defined $prefix;
  my $errpre = $self->errpre;
  $errpre = '' unless defined $errpre;

  print $fh colored($prefix . $errpre . $text,$col);

  # Beep if required
  print STDOUT chr(7) if $self->errbeep;

  tk_update();
  
}


=item throw (text,[colour])

  $prt->throw("An error message");

Same as C<err> method except that an exception of type
C<ORAC::Error::FatalError> is thrown immediately after the error
message is printed.

The message itself is part of the exception that is thrown.

=cut

sub throw {
  my $self = shift;
  $self->err(@_);
  ORAC::Error::FatalError->throw(shift);
}

=item debug (text)

Prints debug messages to the debug filehandle so long as debugging
is turned on.

=cut

sub debug {
  my $self = shift;
  my $text = shift;

  # Check that debug is on
  if ($self->debugmsg) {

    # Read the filehandle
    my $fh = $self->debughdl;
    return unless defined $fh;
    print $fh "DEBUG:$text";
  }
  tk_update();

}

=item tk_update ( )

Does an Tk update on the Main Window widget

=cut

sub tk_update {

  # There is a chance that we have just updated 
  # a Tk text widget. On the off-chance that we have,
  # we should do a Tk update
  try {
     ORAC::Event->update("Tk");
  }
  catch ORAC::Error::FatalError with
  {
     my $Error = shift;
     $Error->throw;    
  }
  catch ORAC::Error::UserAbort with
  {
     my $Error = shift;
     $Error->throw;
  }
  otherwise
  {
     my $Error = shift;
     throw ORAC::Error::FatalError("$Error", ORAC__FATAL);
  };

}

=back

=head1 TIED INTERFACE

An ORAC::Print object can also be tied to filehandle using the
tie command:

  tie *HANDLE, 'ORAC::Print', $prt, 'out|war|err';

where $prt is an ORAC::Print object. Currently all strings printed
to this handle will be redirected to the orac_print command
(and will therefore use the output filehandles associated with the
most recent ORAC::Print object created). The default color used
by the tied handle can be set using the outcol() method of the
object associated with the filehandle

  $prt = new ORAC::Print;
  $prt->outcol('clear');
  tie *HANDLE, 'ORAC::Print', $prt;

will result in all messages printed to HANDLE, being printed
with no color codes to STDOUT.

The optional fourth argument to the tie() command can be used
to set the default output stream. Allowed values are 'out',
'war' and 'err'. These correspond directly to the orac_print,
orac_warn and orac_err commands. Default is to use orac_print
for all tied filehandles.

It is not possible to read from this tied filehandle.

=cut

# Tided handle interface
# usage: tie *HANDLE, "ORAC::Print", $obj
#  $obj is a ORAC::Print object

sub TIEHANDLE {
  my $class = shift;
  my $obj = shift;
  my $out = 'out'; # default to orac_print
  $out = lc(shift) if @_;

  # Store the selected output stream
  # This relies on internals in order to hide the implementation
  # from the rest of the class (ugh!).....
  $obj->{_outtype} = $out;
  return $obj;
}

sub PRINT {
  my $obj = shift;
  # Run orac_* (ie lose all reference to the object)
  # and use the current object and filehandles
  if ($obj->{_outtype} eq 'out') {
    foreach (@_) { orac_print $_, $obj->outcol; }
  } elsif ($obj->{_outtype} eq 'war') {
    foreach (@_) { orac_warn $_, $obj->warncol; }
  } else {
    foreach (@_) { orac_err $_, $obj->errcol; }
  }

}

sub PRINTF {
  my $obj = shift;
  $obj->PRINT(sprintf(shift, @_));
}


=head1 SEE ALSO

L<Term::ANSIColor>, L<IO::Tee>.

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;

