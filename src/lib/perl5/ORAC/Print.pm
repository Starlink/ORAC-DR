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

  $prt->logging(1);
  $prt->logkey( "_PRIMITIVE_NAME_" );
  $prt->out("Log a message" );
  @messages = $prt->msglog();
  $prt->clearlog();

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

use Time::HiRes qw/ gettimeofday /;

$VERSION = '1.0';

$DEBUG = 0;

require Exporter;
@ISA = qw/Exporter/;
@EXPORT = qw/orac_print orac_err orac_warn orac_debug orac_read orac_throw orac_carp
	     orac_printp orac_print_prefix orac_warnp orac_errp orac_say orac_sayp
            orac_msglog orac_clearlog orac_logkey orac_logging orac_loginfo /;

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

=item orac_say( text, [colour] )

Print the supplied text to the ORAC output device(s) using the (optional) supplied colour. A carriage return is automatically appended to the text to be printed.

=cut

sub orac_say {
  my $prt = __curr_obj;
  $prt->say(@_);
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

=item B<orac_sayp>

As for C<orac_say> but includes the prefix that has been specified by using C<orac_print_prefix>

  orac_sayp( $text, $color );

=cut

sub orac_sayp {
  my $prt = __curr_obj;
  my $current = $prt->outpre;
  $prt->outpre( $PREFIX );
  orac_say( @_ );
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

=item B<orac_loginfo>

Register additional information for logging to the file.

  orac_loginfo( %info );

This information is added to the current set although duplicate keys will
overwrite information.

An explicit undef will clear the current information.

  orac_loginfo( undef );

A reference to a hash will force an overwrite of the stored information.

  orac_loginfo( \%info );

To obtain the messages use no arguments:

  %information = orac_loginfo();

=cut

sub orac_loginfo {
  my $prt = __curr_obj;
  $prt->loginfo( @_ );
}

=item B<orac_clearlog>

Clear the message log

  orac_clearlog();

=cut

sub orac_clearlog {
  my $prt = __curr_obj;
  $prt->clearlog;
}

=item B<orac_logkey>

Set the logging key. Usually the primitive name.

  orac_logkey( $primitive );

=cut

sub orac_logkey {
  my $prt = __curr_obj;
  $prt->logkey( @_ );
}

=item B<orac_logging>

Enable or disable logging.

  orac_logging( 1 );

=cut

sub orac_logging {
  my $prt = __curr_obj;
  $prt->logging( @_ );
}

=item B<orac_msglog>

Returns the logged messages.

 @messages = orac_msglog();
 @messages = orac_msglog( $refepoch );

See the msglog() documentation for more information. An undefined reference
epoch is equivalent to no reference epoch.

=cut

sub orac_msglog {
  my $prt = __curr_obj;
  my @messages = $prt->msglog(@_);
  return @messages;
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
  $prt->{Log}      = [];           # Message log
  $prt->{LogKey}   = "NONE";       # Key for log messages
  $prt->{LogMessages} = 0;         # Are we logging messages?
  $prt->{LogInfo}  = {};           # Additional static info

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

=item logging

Enables or disables logging of messages. Default is off.

=cut

sub logging {
  my $self = shift;
  if (@_) { $self->{LogMessages} = shift; }
  return $self->{LogMessages};
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
  $prt->errcol('red');

Currently no check is made that the supplied colour is acceptable.

=cut

sub errcol {
  my $self = shift;
  if (@_) { $self->{ErrColour} = shift; }
  return $self->{ErrColour};
}

=item logkey

String to be associated with output messages. This key will be used when
building up the message stack and can be used for grouping purposes.

  $prt->logkey( "_IMAGING_HELLO_" );

Usually this would reflect the current primitive.

=cut

sub logkey {
  my $self = shift;
  if (@_) { $self->{LogKey} = shift; }
  return $self->{LogKey};
}

=item loginfo

Register additional information for logging to the file.

  $prt->loginfo( %info );
  $prt->loginfo( KEY => 'value' );

This information is added to the current set although duplicate keys will
overwrite information.

An undef will delete the key

  $prt->loginfo( KEY => undef );

An explicit undef will clear the current information.

  $prt->loginfo( undef );

A reference to a hash will force an overwrite of the stored information.

  $prt->loginfo( \%info );

To obtain the messages use no arguments:

  %information = $prt->loginfo();

The information is associated with each change of logkey and so can be
updated each time a logkey is updated.

=cut

sub loginfo {
  my $self = shift;
  if (@_) {
    my %info;
    if (! defined( $_[0] ) ) {
      %info = ();
    } elsif ( ref($_[0]) eq "HASH" ) {
      %info = %{$_[0]};
    } else {
      %info = (%{$self->{LogInfo}}, @_);
    }
    # remove undefs
    for my $k (keys %info) {
      delete $info{$k} unless defined $info{$k};
    }
    %{$self->{LogInfo}} = %info;
  }
  return %{$self->{LogInfo}};
}

=item msglog

Array of all logged messages.

 @messages = $self->msglog();

Each entry is a reference to an array with elements

 0 logkey value at time of message
 1 epoch of message
 2 reference to array of messages
 3 reference to hash of log information

ie [ prim1, epoch, \@msg, \%info ], [ prim2, epoch2, \@msg, \%info ]

Messages will be in epoch order. If an argument is given
this will be a reference epoch. Only messages more recent
than this will be returned. Only works in list context.

 @messages = $self->msglog( $refepoch );

An undefined reference epoch is ignored.

=cut

sub msglog {
  my $self = shift;
  my $refepoch = shift;
  if (defined $refepoch) {
    my $ref = shift;
    my $LOG = $self->{Log};
    # we could use a clever bisection algorithm since we know
    # they are in order but until the profiler tells me there
    # is a problem we will do it the easy way
    my $refindex;
    for my $i (0..$#$LOG) {
      if ($LOG->[$i]->[1] >= $ref) {
        $refindex = $i;
      }
    }

    if (defined $refindex) {
      return @$LOG[$refindex..$#$LOG];
    }
    return ();
  } else {
    return (wantarray ? @{$self->{Log}} : $self->{Log} );
  }
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
out() or say() methods. Default is to have no prefix.

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
war() or carp() methods. Default is to have the string 'Warning:' prepended.

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
err() method. Default is to have the string 'Error:' prepended.

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

  my $outtext = $prefix . $outpre . $text;
  print $fh colored($outtext ,$col);

  # store the message
  $self->_store_msg( $outtext );
  
  tk_update();
  
}

=item say( text, [col] )

Print output messages, appending a carriage return to the text string.

By default messages are written to STDOUT. This can be overridden with the outhdl() method.

=cut

sub say {
  my $self = shift;
  return unless @_;
  my $text = shift;

  my $col = $self->outcol;
  if( @_ ) { $col = shift; }

  $self->out( $text . "\n", $col );
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

  my $outtext = $prefix . $warpre . $text;
  print $fh colored($outtext,$col);

  # store the message
  $self->_store_msg( $outtext );

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

  my $outtext = $prefix . $errpre . $text;
  print $fh colored($outtext,$col);

  # store the message
  $self->_store_msg( $outtext );

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

=item clearlog

Clear the log. This can be used to reset logged messages when a new recipe
begins.

  $prt->clearlog();

=cut

sub clearlog {
  my $self = shift;
  my $LOG = $self->msglog;
  @$LOG = ();
  return;
}

=begin PRIVATE METHODS

=item B<_store_msg>

Store the supplied text along with a datestamp and any registered associated
key.

  $prt->_store_msg( $text );

Messages are stored in an array in the order they were printed. Colours
and prefixes are retained.

Each entry in the array is a reference to an array with elements:

 0 log key associated with message (Eg primitive name)
 1 gettimeofday() floating point epoch
 2 reference to array of messages in order
 3 reference to hash of loginfo

so if multiple messages arrive from a single logkey value they are combined.

ie [ prim1, epoch, \@msg, \%info ], [ prim2, epoch2, \@msg, \%info ]

Only one epoch stored per log key, since we are only interested in writing
a single history block per primitive.

Does nothing if logging() is false.

=cut

sub _store_msg {
  my $self = shift;
  my $text = shift;

  return unless $self->logging();
  my $date = gettimeofday();

  # Get the message, key and info
  my $LOG = $self->msglog();
  my $logkey = $self->logkey;
  my %info = $self->loginfo;

  # see if we have a match to the current logkey already
  if (@$LOG && $LOG->[-1]->[0] eq $logkey) {
    # already have a slot
  } else {
    # create a new slot
    push(@$LOG, [ $logkey, $date, [], \%info ] );
  }

  # Break the supplied text into an array with breaks on newlines
  my @textlines = split(/\n/,$text);

  # store the message
  push(@{$LOG->[-1]->[2]}, @textlines);

  return;
}


=end PRIVATE METHODS

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
  } elsif ($obj->{_outtype} eq 'say') {
    foreach (@_) { orac_say $_, $obj->outcol; }
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

