package ORAC::Display::GAIA;

=head1 NAME

ORAC::Display::GAIA - ORAC interface to GAIA

=head1 SYNOPSIS

  $disp = new ORAC::Display::GAIA;

  $disp->image($file);

=head1 DESCRIPTION

ORAC interface to the the GAIA (ESO Skycat) display tool. Provides methods
for displaying images.

Available options are:

IMAGE - display image in GAIA window

=cut

use 5.004;

use Carp;
use strict;

use base qw/ ORAC::Display::Base /;  # Base class

use ORAC::Print;
use ORAC::Constants qw/:status/;

use IO::Socket;  # For socket connection to Gaia
use IO::Select;

use Sys::Hostname; # Special case ukirt
use Cwd qw/ getcwd /;         # To get current working directory

use vars qw/ $VERSION $DEBUG /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);
$DEBUG   = 0;

# Store the hostname (even though hostname does cache)
my $localhost = hostname;

=head1 PUBLIC METHODS

=head2 Constructor

=over 4

=item B<new>

Object constructor. The constructor starts up a new version of
GAIA (if one is not running) and connects via a socket.

The program aborts if there is an error launching or contacting
gaia.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create a new instance from the base class
  # Dont allow any arguments.
  # Probably should turn off -w here
  my $disp = $class->SUPER::new(Sock => undef,
                                Sel => IO::Select->new,
                                ConnectToRemoteGAIA => 1,
                                Launchable => 1,
                               );

  # SPECIAL CASE UKIRT FOR NOW
  $disp->use_remote_gaia(0) if $localhost =~ /kauwa/;

  # Now try to launch Gaia

  $disp->launch;


  my $status = $disp->configure;

  if ($status != ORAC__OK) {
    croak "Error launching/contacting or configuring Gaia. It is unlikely that this can be fixed by retrying from within ORAC-DR. Try deleting the ~/.skycat/history file and restarting ORAC-DR. If that does not work, please rerun either with the display switched off or with a different display device selected.";
  }

  # Return object
  return $disp;

}

=back

=head2 Accessor Methods

=over 4

=item B<launchable>

Whether or not GAIA can be automatically launched.

  $gaia->launchable( 0 );

Defaults to true. If this is set to false (0), then a new GAIA will
never be started.

=cut

sub launchable {
  my $self = shift;
  if( @_ ) { $self->{Launchable} = shift; }
  return $self->{Launchable};
}

=item B<sock>

Returns or sets the socket to Gaia. Private to this class.

  $sock = $gaia->sock();

This is usually IO::Socket object. This socket is automatically
added to the IO::Select object returned by the C<sel> method.
(and all previous sockets registered with the IO::Select object
are removed).

=cut

sub sock {
  my $self = shift;
  if (@_) {
    # Read the socket
    $self->{Sock} = shift;
    # Clear all previous entries from the IO::Select object
    $self->sel->remove( $self->sel->handles );

    # Add this socket to the IO::Select object
    $self->sel->add( $self->{Sock} );
  }
  return $self->{Sock};
}

=item B<sel>

Returns the IO::Select object associated associated with the
current socket.

  $select = $gaia->sel();

This object is used to determine whether the GAIA process can be
contacted through the established socket connection.

=cut

sub sel {
  my $self = shift;
  return $self->{Sel};
}

=item B<use_remote_gaia>

Controls whether we are allowed to connect to a GAIA process that
is already running on a remote machine. By default this is allowed
(true) but in some cases you may not want to connect to a remote
GAIA. For example, at UKIRT, the display must be sent to the machine
running the pipeline and not one of the other GAIAs that are running
on separate machines for QuickLook and general data inspection.

=cut

sub use_remote_gaia {
  my $self = shift;
  if (@_) { $self->{ConnectToRemoteGAIA} = shift; }
  return $self->{ConnectToRemoteGAIA};
}

=back

=head2 General Methods

=over 4

=item B<create_dev>

Clone a new GAIA window and associate it with 'win'. This is different
to launching a new display device (ie running up GAIA itself).

  $status = $Display->create_dev($win, $name);

For GAIA (V E<lt>= 2.3-2) the device name ($name) must be an integer.
(enforced if the newdev() method is used).

ORAC status is returned. 

=cut

sub create_dev {

  my $self = shift;
  my $win = shift;
  my $name = shift;

  # We launch with the ORAC display image
  my $image = "$ENV{ORAC_DIR}/images/orac_start.sdf";

  # Need to clone from the default window (called default)
  my $base = $self->dev('default');

  # With v2.3-2 of GAIA the automatic naming of clones does not
  # work correctly so we must name them explicitly. Integers are expected.
  # Now clone the window and grab the result
  my ($status, $clone) = 
    $self->send_to_gaia("$base noblock_clone $name $image");

  if ($status != ORAC__OK) {
    # Error
    orac_err "ORAC::Display::GAIA - Error launching clone window\n";
    die "Error: $clone\n";
    return ORAC__ERROR;
  } else {
    # Now store the clone window
    $self->dev($win, $clone);    
  }

  # Wait for GAIA to configure itself
  # need the delay to prevent us sending the next request before
  # the gaia internals recognise the new clone
  # Choose to do this by asking gaia to tell us when the window
  # exists rather than simply sleeping for N seconds
  while (1) {
    my ($status, $exists) = $self->send_to_gaia("winfo exists $clone.image");
    last if ($status == ORAC__OK && $exists);
  }

  return ORAC__OK;
}




=item B<launch>

Connect to a pre-existing Gaia process or launch a new Gaia process.
If the first connection attempt fails, launches a new gaia process.
After this, attempts to connect to a new gaia process every 3 seconds
and attempts to launch a new gaia process every 60 seconds.
A maximum of 5 attempts are made (5 minutes) to launch a new Gaia
process before giving up.

There is no return status -- the program croaks if it can not
get a connection to GAIA !!

Whilst it is waiting, does not attempt to keep a L<Tk|Tk> event loop
running.

=cut

sub launch {
  my $self = shift;

  my $MAX_TRIES = 5;          # Number of attempts to launch new gaia
  my $timegap_to_check  = 3;  # in seconds
  my $timegap_to_launch = 20; # in units of $timegap_to_check

  # Set the RTD_REMOTE_DIR environment variable to $ORAC_DATA_OUT
  # if it's not already set.
  if( ! defined( $ENV{'RTD_REMOTE_DIR'} ) ) {
    $ENV{'RTD_REMOTE_DIR'} = $ENV{'ORAC_DATA_OUT'};
  }

 # First attempt to simply connect
  my $sock = $self->_open_gaia_socket();

  if ($sock) {
    $self->sock( $sock );
    return;
  }

  if( $self->launchable ) {

    # Now launch a new gaia
    $self->_launch_new_gaia();

    my $tries = 0;
    while ($tries < $MAX_TRIES) {

      # Check for a connection timegap_to_launch tries
      foreach (1..$timegap_to_launch) {

        print "GAIA Connection loop $_\n" if $DEBUG;

        # pause
        sleep $timegap_to_check;

        # Check for connection
        my $sock = $self->_open_gaia_socket;

        if ($sock) {
          # Store it and return
          $self->sock( $sock );
          return;
        }

      }

      # Okay - didn't work, launch a new gaia (this is not a method)
      $self->_launch_new_gaia();

      # increment counter
      $tries++;

    }

  }

  croak "TIMEOUT: Could not connect to gaia\n";

}


# internal method to open the socket
# no arguments. Looks for .rtd-remote file in $RTD_REMOTE_DIR and
# then home directory
# Returns a socket object if successful, otherwise returns undef
# Does not update the object state

# $sock = $self->_open_gaia_socket;

# Reads .rtd_remote file and attempts to connect

sub _open_gaia_socket {

  my $self = shift;
  my $fh;

  # Attempt to open .rtd-remote file in RTD_REMOTE_DIR.

  if( defined( $ENV{'RTD_REMOTE_DIR'} ) ) {

    my $path = File::Spec->catdir( $ENV{RTD_REMOTE_DIR}, ".rtd-remote");
    print "Looking in path: $path\n" if $DEBUG;

    if ($fh = new IO::File($path)) {
      my ($pid, $host, $port) = split (/\s+/, <$fh>);
      print "host = $host,   pid = $pid,    port = $port\n" if $DEBUG;
      close $fh;

      # We are allowed to try and connect to this gaia if we 
      # can talk to remote gaias or if the host mentioned in the 
      # file matches the host we are running on
      if ($self->use_remote_gaia || $host =~ /$localhost/) {

        # Open the socket connection
        my $sock = IO::Socket::INET->new(
                                         Proto => "tcp",
                                         PeerAddr  => $host,
                                         PeerPort  => $port,
                                        );
        if ($sock) {
          print "Opened GAIA on $path\n" if $DEBUG;
          $sock->autoflush(1);
          return $sock;
        }
      }
    }
  }

  return undef;
}

# internal sub to launch a new gaia process
# no args. Returns ORAC status

# This is a Class method (does not require an object)

#  $status = ORAC::Display::GAIA->_launch_new_gaia;

sub _launch_new_gaia {

  orac_print "Launching a new GAIA process\n";
  my $status = system "$ENV{GAIA_DIR}/gaia.sh -show_hdu_chooser 0 &";

  if ($status == 0) {
    $status = ORAC__OK;
  } else {
    $status = ORAC__ERROR;
  }

  return $status;
}


=item B<configure>

Load the startup image into GAIA. Essentially used to test that
GAIA can display images correctly.

Returns ORAC status.

=cut

sub configure {

  my $self = shift;
  
  my $startup = "$ENV{ORAC_DIR}/images/orac_start.sdf";

  # Need to retrieve the name of the default window from
  # gaia itself using the get_image command.

  my ($status, $gaia_objects) = $self->send_to_gaia("get_skycat_images");

  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - Unable to retrieve skycat image list\n";
    orac_err "Error: $gaia_objects\n";
    return ORAC__ERROR;
  }

  # Now we need to split this return string on spaces and 
  # get the first image name
  my $default = (split(/\s+/,$gaia_objects))[0];

  # Load the startup image
  my $result;
  ($status, $result) = $self->send_to_gaia("$default configure -hdu 0");
  ($status, $result) = $self->send_to_gaia("$default configure -file $startup");

  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - Unable to display startup image\n";
    orac_err "Error: $result\n";
    return ORAC__ERROR;
  }

  # Get the id associated with the actual display widget
  # so that we can cut
  my $dispwid;
  ($status, $dispwid) = $self->send_to_gaia("$default get_image");
  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - unable to get display widget\n";
    orac_err "Error: $dispwid\n";
    return ORAC__ERROR;
  }

  ($status, $result) = $self->send_to_gaia("$dispwid autocut -percent 100");
  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - unable to adjust autocut\n";
    orac_err "Error: $result\n";
    return ORAC__ERROR;
  }


  # Expect $default to have the form .xxxn.image where 
  # .nnn is .rtdN for older gaias and .gaiaN for newer
  # versions (those with contouring >= 2.3-0). Split on second '.'
  # Use split rather than substr since we cant guarantee the length
  $default = "." . (split(/\./,$default))[1];

  # Everything okay so store the name of the GAIA window
  $self->dev('default', $default);

  return ORAC__OK;

}


=item B<send_to_gaia>

Sends the supplied command to gaia. Any response from Gaia is returned.

  ($status, $return_string) = $obj->send_to_gaia('command');
  ($status, @return_strings) = $obj->send_to_gaia(@commands);

The returned status is translated into an ORAC status (either ORAC__OK
or ORAC__ERROR). On error, the return_string contains the error message.
The status returned is the status of the last command processed by GAIA.

=cut


sub send_to_gaia {
  my $self = shift;

  croak 'Usage: send_to_gaia(commands)' unless @_;

  my @command = @_;
  my @results;
  my $num_commands = @command;
  print "number of commands = $num_commands\n" if $DEBUG;


  # Combine all the commands into a single string prefixed by
  # remotetcl (the internal gaia command for evaluating tcl strings)
  my $command = '';
  foreach (@command) {
    $command .= "remotetcl \"$_\"\n";
  }
  print "\n************ GAIA Command: $command\n" if $DEBUG;

  # Check socket
  # Set timeout for GAIA select() checks.
  # No point waiting longer than 30 seconds even if images are very large
  my $timeout = 30.0;

  # have a problem if returns undef from can_write
  # Return if we can't write to the socket
  return (ORAC__ERROR, 'Socket not writable - timeout')
    unless $self->sel->can_write($timeout);

  # Get the socket object
  my $sock = $self->sock();

  # Send the command to gaia
  print "prepping to send..." if $DEBUG;
  print $sock $command;
  print "completed send...\n" if $DEBUG;

  # set up a status variable
  my $status;

  # We expect to receive a reply from GAIA
  # for each command we sent so loop over each command

  for my $i ( 1 .. $num_commands ) {

    print "prepping to receive..." if $DEBUG;

    # Check that the socket is readable, up to timeout

    return (ORAC__ERROR, 'GAIA Socket not readable - timeout')
      unless $self->sel->can_read($timeout);

    # Receive the first status string (should be a status and a list of bytes
    # terminated with a \n
    # We keep on reading a single character at a time until we
    # get a \n.
    # We can not use <$sock> in this case since we have printed to
    # it earlier.
    # Go into an infinite loop until we get a \n
    # Do not count the number of loops - hopefully the recv will
    # fail if we get into trouble.

    my $result = '';
    while ( 1 ) {
      # Recv should return undef on error but this does not seem
      # to work on Solaris -- check for $! explicitly instead!!!
      recv ($sock, my $reply1, 1, 0);
      return (ORAC__ERROR, "Error reading initial byte stream from GAIA socket: $!") if $!;

      # Return with an error if the socket read returns a null string
      # We could also delete the socket object but this will be done
      # automatically when the next send fails. This is not pretty but
      # is quicker than attempting to modify the class to support an
      # undefined socket and automatic relaunching when the socket is undef.
      return (ORAC__ERROR, "Read null string from GAIA socket. Assuming GAIA has died\n") if $reply1 eq '';

      # Jump out the loop if we have a newline
      last if $reply1 eq "\n";

      # Append the new byte
      $result .= $reply1;
    }

    # We now have the initial response from GAIA.
    # Should be a status code and the number of bytes to receive
    # If the status is bad (!=0) we still need to receive the message
    # since that is then the error message

    ($status, my $nbytes) = split /\s/, $result,2;
    print "completed receive of status and byte length...\n" if $DEBUG;
    print "Command number = $i  Status $status NBytes $nbytes\n" 
      if $DEBUG;


    # If the number of bytes to receive is greater than 4096 we
    # have to break the read of the reply into smaller chunks of
    # 4096 bytes each

    my $message = ''; # The reply string
    while ($nbytes > 0) {

      # Work out how many bytes to look for
      # Either 4096 or the number we have left if lower
      my $recvbytes = ($nbytes > 4096 ? 4096 : $nbytes);

      print "Preparing to receive $recvbytes bytes from GAIA\n" if $DEBUG;
      # Recv should return undef on error but this does not seem
      # to work on Solaris -- check for $! explicitly instead!!!
      recv ($sock, my $reply2, $recvbytes, 0);
      return (ORAC__ERROR, "Error reading data from GAIA socket: $!")
	if $!;

      # Return with an error if the socket read returns a null string
      return (ORAC__ERROR, "Read null string from GAIA socket. Assuming GAIA has died\n") if $reply2 eq '';

      # Append the string
      $message .= $reply2;

      # Reduce nbytes by 4096 and loop if required
      $nbytes -= 4096;

    }

    # Store the final message into the array
    push (@results, $message);
    print "results received for command $i: $message\n" if $DEBUG;
  }
  
  # Translate status code
  if ($status == 0) {
    $status = ORAC__OK;
  } else {
    $status = ORAC__ERROR;
  }

  # Return the results
  return ($status, @results);
}


=item B<newdev>

Returns the name to be used for the new GAIA window based on the supplied
window name.

   $name = $obj->newdev($win);

Currently, for gaia, the argument is ignored. The name is simply returned
as an integer calculated from the number of devices already stored
in the object.

=cut

sub newdev {
  my $self = shift;

  # New Window name is simply the number of keys ('default' is in twice)
  # This allows us to name the clone
  my $i = scalar ( keys %{ $self->dev } );

  return $i;
}

=back

=head1 DISPLAY METHODS

=over 4

=item B<image>

Routine to display images in Gaia. Note that the full file name is required.
If an image name does not include an extension then '.sdf' is appended.
(ie NDF is assumed).

Takes a file name and arguments stored in a hash.

  $disp->image("filename", \%options)
  $disp->image("filename", { WINDOW => 2 });

Currently no image sectioning is supported.
Display range can be adjusted with ZAUTOSCALE, ZMIN and ZMAX.

Note that for GAIA, ZAUTOSCALE implies a 95 percent cut level and
not 100 percent.

Will attempt to relaunch GAIA if it can not be contacted.
Will attempt to create a new clone window if a clone can not be
contacted even though it has been used previously.

ORAC status is returned.

=cut


sub image {

  my $self = shift;
  my $file = shift;


  # Check file for extension. If this is a MEF then escape the square brackets
  # so that the extension number is interpreted properly. Also bump up the 
  # value of the extension number as GAIA starts from 1 rather than 0 like
  # everyone else...

  if ($file =~ /^(.*?)\[(\d+)\]$/) {
    $file = sprintf("%s\\\\[%d\\\\]",$1,$2+1);

  # Assume that an extension is a . followed by letters but not a /

  } else {
    unless ($file =~ /\.\w+$/) {
      $file .= ".sdf";
    }
  }

  # We probably should append the full path since we dont know 
  # which directory gaia will use be default
  # Check for a leading '/' indicating a full path name
  # use getcwd because cwd sometimes doesn't work on alpha
  unless ($file =~ /^\s*\//) {
    my $cwd = getcwd;
    if (defined $cwd && length($cwd) > 0) {
      $file = "$cwd/$file";
    } else {
      orac_warn "ORAC::Display::GAIA: Could not determine current working directory.\n";
      orac_warn "GAIA may not be able to locate file $file\n";
    }
  }

  # Read the options hash
  my $opt;
  my %options = ();
  if (@_) {
    $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }


  # Get the window name from the options hash
  my $window = 'default';
  if (exists $options{WINDOW}) {
    $window = $options{WINDOW};
  }
  # and convert it into a device id
  my $device = $self->window_dev($window);

  # Need to test that the device actually exists even if gaia 
  # is running
  my ($status, $exists) = $self->send_to_gaia("winfo exists $device");

  if ($status == ORAC__OK) {
    unless ($exists) {
      # Window does not exist so we should try to relaunch it
      # Need to get the ID name from the requested device name
      # this is the number at the end of the device string
      $device =~ /(\d+)$/;
      my $name = $1;
      if (defined $name) {
	orac_warn "Attempting to restart GAIA window $window ($device)\n";
	$status = $self->create_dev($window, $name);
	return $status if $status == ORAC__ERROR;
      } else {
	orac_err "Could not determine GAIA name from $device\n";
	orac_err "Therefore could not try to relaunch clone window $window\n";
	return ORAC__ERROR;
      }

    }
  } else {
    # This probably means that GAIA is no longer attached to the
    # socket. WE have the ability to try to relaunch if required.....
    # That would require use clearing the device lookup table
    # and rerunning launch() and configure()
    orac_warn "Could not talk to GAIA. Attempting to relaunch GAIA\n";
    %{ $self->dev } = ();
    $self->launch;
    $status = $self->configure;
    $device = $self->window_dev($window); # Get an updated device name
  }

  
  # We now need to retrieve the image id associated with this
  # clone from gaia
  ($status, my $image) = $self->send_to_gaia("$device get_image");

  # Should be able to check the error message from herre and attempt
  # to relaunch a missing window.
  if ($status != ORAC__OK) {
    orac_err "Error: $image\n";
    orac_err "ORAC::Display::GAIA - Error retrieving image id\n";
    orac_err "Lost connection to GAIA window! Did you close it by mistake?\n".
      "Will attempt to relaunch GAIA next time around\n".
      "Restart the pipeline at a convenient time if this fails\n".
	"If you want to have fewer GAIA windows\n".
	  "configure your display - type \"oracman Display\" for info.\n";

    return ORAC__ERROR;
  }

  # Copy the file to a temporary file before sending to GAIA. This
  # gets around a memory mapping bug that will be fixed properly, but
  # not in the puana branch.
  my $tmpfile = "GaiaTemp$$";
  unlink( $tmpfile . ".sdf" );

  ( my $rootfile, my $rest ) = split /\./, $file, 2;

  use File::Copy;
  copy( $rootfile . ".sdf", $tmpfile . ".sdf" );

  # Just send to GAIA - configure the new file
  my $junk;
#  ($status, $junk) = $self->send_to_gaia("$image configure -file $file");
  ($status, $junk) = $self->send_to_gaia("$device open ${tmpfile}.${rest}");

  if ($status != ORAC__OK) {
    orac_err "Error: $junk\n";
    orac_err "ORAC::Display::GAIA - Error displaying file $file\n";
    return ORAC__ERROR;
  }

  # Other options go here for dealing with ZAUTOSCALE etc
  # To adjust cut levels we need to find the name of the display widget
  # rather than the Gaia window
#  my $ctrlimg = $self->send_to_gaia("$image get_image");
  ($status, my $dispwid) = $self->send_to_gaia("$image get_image");

  if ($status != ORAC__OK) {
    orac_err "Error: $dispwid\n";
    orac_err "ORAC::Display::GAIA - Error retrieving sub-image\n";
    return ORAC__ERROR;
  }


  # Now can modify cut levels
  if ($options{ZAUTOSCALE}) {
    # Set autocut to 95
    ($status, $junk) = $self->send_to_gaia("$dispwid autocut -percent 95");

  if ($status != ORAC__OK) {
    orac_err "Error: $junk\n";
    orac_err "ORAC::Display::GAIA - Error auto cutting display window: $dispwid\n";
    return ORAC__ERROR;
  }


  } else {
    # No autoscaling
    my $min = $options{ZMIN};
    my $max = $options{ZMAX};
    if (defined $min && defined $max) {
      ($status, $junk) = $self->send_to_gaia("$dispwid cut $min $max");

      if ($status != ORAC__OK) {
	orac_err "ORAC::Display::GAIA - Error setting max/min display window: $dispwid\n";
	orac_err "Error: $junk\n";
	return ORAC__ERROR;
      }

    }
  }

  # Ask the panel to reflect any changes
  ($status, my $panel) = $self->send_to_gaia("$image component info");

  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - Error updating info panel\n";
    orac_err "Error: $panel\n";
    return ORAC__ERROR;
  }

  ($status, $junk) = $self->send_to_gaia("$panel updateValues");

  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - Error updating panel\n";
    orac_err "Error: $junk\n";
    return ORAC__ERROR;
  }


  return $status;

}

=back

=head1 SEE ALSO

L<ORAC::Display::Base>, L<ORAC::Display::KAPVIEW>, L<ORAC::Display>,
L<IO::Socket>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu).
Communication code written initially by Casey Best (cbest@uvic.ca)
based on tcl code from Peter Draper.

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
