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

use Cwd qw/ cwd /;         # To get current working directory

use vars qw/ $VERSION $DEBUG /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);
$DEBUG   = 0;


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
  my $disp = $class->SUPER::new(Sock => undef, Sel => IO::Select->new);

  # Now try to launch Gaia

  $disp->launch;
  my $status = $disp->configure;

  if ($status != ORAC__OK) {
    croak "Error launching/contacting or configuring Gaia. It is unlikely that this can be fixed by retrying from within ORACDR. Please rerun either with the display switched off or with a different display device selected.";
  }

  # Return object
  return $disp;

}

=back

=head2 Accessor Methods

=over 4

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


=back

=head2 General Methods

=over 4

=item B<create_dev>

Clone a new GAIA window and associate it with 'win'. This is different
to launching a new display device (ie running up GAIA itself).

  $status = $Display->create_dev($win);

ORAC status is returned.

=cut

sub create_dev {

  my $self = shift;
  my $win = shift;

  # We launch with the ORAC display image
  my $image = "$ENV{ORAC_DIR}/images/orac_start.sdf";

  # Need to clone from the default window (called default)
  my $base = $self->dev('default');

  # Now clone the window and grab the result
  my ($status, $clone) = $self->send_to_gaia("$base clone {} $image");

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
  orac_warn "Sleeping.......\n";
  sleep 5;

  return ORAC__OK;
}




=item B<launch>

Connect to a pre-existing Gaia process or launch a new Gaia process.

=cut

sub launch {
  my $self = shift;

  my $done = 0;
  my $tries = 0;
  while (!$done && $tries <18) {
    my $fh;
    if ($fh = new IO::File($ENV{HOME}.'/.rtd-remote')) {
      my ($pid, $host, $port) = split (/\s+/, <$fh>);
      print "host = $host,   pid = $pid,    port = $port\n" if $DEBUG;
      close $fh;
      my $sock = IO::Socket::INET->new( 
           Proto => "tcp",
           PeerAddr  => $host,
           PeerPort  => $port,
      );
      if ($sock) {
        $self->sock( $sock );
        $done = 1;
        $self->sock()->autoflush(1);
      } else {
	orac_print "Could not connect to current process: Launching a new Gaia process\n";
        system "$ENV{GAIA_DIR}/gaia.sh &";
        sleep 20;
      }
    } else {
      orac_print "Launching a new Gaia process\n";
      system "$ENV{GAIA_DIR}/gaia.sh &";
      sleep 20;
    }
    $tries++;
  }
  die "TIMEOUT: Could not connect to gaia\n" if (!$self->sock());

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

=cut


sub send_to_gaia {
  my $self = shift;

  croak 'Usage: send_to_gaia(commands)' unless @_;

  my @command = @_;
  my @results;
  my $command = '';
  my $num_commands = @command;
  print "number of commands = $num_commands\n" if $DEBUG;
  my ($reply, $reply2, $result);
  my $message = '';
  foreach (@command) {
    $command .= "remotetcl \"$_\"\n";
  }
  print "\n************ GAIA Command: $command\n" if $DEBUG;
  my $sock = $self->sock();

  # Check socket
  my $timeout = 30.0;
  my $res = $self->sel->can_write($timeout);

  # have a problem if returns undef from can_write
  unless (defined $res) {
    orac_err "Error - GAIA socket is not writable. Timeout!\n";
    return (ORAC__ERROR, 'Socket not writable - timeout');
  }

  print "prepping to send..." if $DEBUG;
  print $sock $command;
  print "completed send...\n" if $DEBUG;
  $message = '';
  my $status;
  for ( my $i = 0; $i < $num_commands; $i++ ) {
    $reply2 = '';
    print "prepping to receive..." if $DEBUG;
    my $a = '';
    $reply2 = '';

    # Check that the socket is readable, up to timeout
    my $res = $self->sel->can_read($timeout);

    unless (defined $res) {
      orac_err "send_to_gaia: Error - GAIA socket is not readable\n";
      return (ORAC__ERROR, 'Socket not readable - timeout');
    }

    # Receive the first status string (should be a status and a list of bytes
    # terminated with a \n
    while (!($reply2 =~ /[\n]/)) {
      recv ($sock, $reply2, 1, 0);
      $a.=$reply2;
    }
    $result = $a;
    print "completed receive of status and byte length...\n" if $DEBUG;
    print "i = $i.  results = $result\n" if $DEBUG;
    ($status, my $byte) = split / /, $result,2;
    while ($byte > 4096) {
      print "bytes are huge!!\n" if $DEBUG;
      recv ($sock, $reply2, 4096, 0); 
      $byte -=4096;
      $message .= $reply2;
    }
    print "prepping to receive actual data...\n" if $DEBUG;
    
    recv ($sock, $reply, $byte, 0);
    $message .= $reply;
    push (@results, $message);
    print "results received: $message\n" if $DEBUG;
    $message = '';
  }
  
  # Translate status code
  if ($status == 0) {
    $status = ORAC__OK;
  } else {
    $status = ORAC__ERROR;
  }

  # Return the results
  return ($status, $results[0])  if ($num_commands < 2);
  return ($status, @results);
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


Currently no image sectioning is supported.
Display range can be adjusted with ZAUTOSCALE, ZMIN and ZMAX.

Note that for GAIA, ZAUTOSCALE implies a 95 percent cut level and
not 100 percent.

ORAC status is returned.

=cut


sub image {

  my $self = shift;
  my $file = shift;


  # Check file for extension
  # Assume that an extension is a . followed by letters but not a /
  unless ($file =~ /\.\w+$/) {
    $file .= ".sdf";
  }

  # We probably should append the full path since we dont know 
  # which directory gaia will use be default
  # Check for a leading '/' indicating a full path name
  unless ($file =~ /^\s*\//) {
    my $cwd = cwd;
    $file = "$cwd/$file";
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
  
  # We now need to retrieve the image id associated with this
  # clone from gaia
  my ($status, $image) = $self->send_to_gaia("$device get_image");

  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - Error retrieving image id\n";
    orac_err "Error: $image\n";
    return ORAC__ERROR;
  }

  # Just send to GAIA - configure the new file
  my $junk;
  ($status, $junk) = $self->send_to_gaia("$image configure -file $file");

  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - Error displaying file $file\n";
    orac_err "Error: $junk\n";
    return ORAC__ERROR;
  }


  # Other options go here for dealing with ZAUTOSCALE etc
  # To adjust cut levels we need to find the name of the display widget
  # rather than the Gaia window
#  my $ctrlimg = $self->send_to_gaia("$image get_image");
  ($status, my $dispwid) = $self->send_to_gaia("$image get_image");

  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - Error retrieving sub-image\n";
    orac_err "Error: $dispwid\n";
    return ORAC__ERROR;
  }


  # Now can modify cut levels
  if ($options{ZAUTOSCALE}) {
    # Set autocut to 95
    ($status, $junk) = $self->send_to_gaia("$dispwid autocut -percent 95");

  if ($status != ORAC__OK) {
    orac_err "ORAC::Display::GAIA - Error auto cutting\n";
    orac_err "Error: $junk\n";
    return ORAC__ERROR;
  }


  } else {
    # No autoscaling
    my $min = $options{ZMIN};
    my $max = $options{ZMAX};
    if (defined $min && defined $max) {
      ($status, $junk) = $self->send_to_gaia("$dispwid cut $min $max");

      if ($status != ORAC__OK) {
	orac_err "ORAC::Display::GAIA - Error setting max/min\n";
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

L<ORAC::Display::Base>, L<ORAC::Display::KAPVIEW>, L<ORAC::Display>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu) and Casey Best (cbest@uvic.ca).

=cut


1;
