package ORAC::Display::GAIA;

=head1 NAME

ORAC::Display::GAIA - ORAC interface to GAIA

=head1 SYNOPSIS

  $disp = new ORAC::Display::GAIA;

  $disp->image();

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

use Cwd qw/ cwd /;         # To get current working directory

use vars qw/ $VERSION $DEBUG /;

$VERSION = '0.10';
$DEBUG   = 0;


=head1 PUBLIC METHODS

=over 4

=item new

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
  my $disp = $class->SUPER::new(Sock => undef);

  # Now try to launch Gaia

  $disp->launch;
  my $status = $disp->configure;

  if ($status != ORAC__OK) {
    croak "Error launching/contacting or configuring Gaia. It is unlikely that this can be fixed by retrying from within ORACDR. Please rerun either with the display switched off or with a different display device selected.";
  }

  # Return object
  return $disp;

}

=item sock 

Returns or sets the socket to Gaia. Private to this class.

  $sock = $gaia->sock();

=cut

sub sock {
  my $self = shift;
  $self->{SOCK} = shift if @_;
  return $self->{SOCK};
}

=item create_dev(win)

Clone a new GAIA window and associate it with 'win'. This is different
to launching a new display device (ie running up GAIA itself).

=cut

sub create_dev {

  my $self = shift;
  my $win = shift;

  # We launch with the ORAC display image
  my $image = "$ENV{ORAC_DIR}/images/orac_start.sdf";

  # Need to clone from the default window (called default)
  my $base = $self->dev('default');

  # Now clone the window and grab the result
  my $clone = $self->send_to_gaia("$base clone {} $image");

  # Now store the clone window
  $self->dev($win, $clone);

}




=item launch

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
      sleep 5;
    }
    $tries++;
  }
  die "TIMEOUT: Could not connect to gaia\n" if (!$self->sock());

}


=item configure

Load the startup image into GAIA.


=cut

sub configure {

  my $self = shift;
  
  my $startup = "$ENV{ORAC_DIR}/images/orac_start.sdf";

  # Need to retrieve the name of the default window from
  # gaia itself using the get_image command.

  my $gaia_objects = $self->send_to_gaia("SkyCat::get_skycat_images");

  # Now we need to split this return string on spaces and 
  # get the first image name
  my $default = (split(/\s+/,$gaia_objects))[0];

  # Load the startup image
  my $result = $self->send_to_gaia("$default configure -file $startup");

  # Note that this is of the form .rtdn.image
  # We need to store the .rtdn bit
  $default = substr($default, 0,5);

  # If the result contains something then this indicates an error
  # So return ORAC__ERROR
  if ($result) {
    return ORAC__ERROR;
  } else {
    # Everything okay so store the name of the GAIA window
    $self->dev('default', $default);

    return ORAC__OK;
  }


}


=item send_to_gaia

Sends the supplied command to gaia. Any response from Gaia is returned.

  $obj->send_to_gaia('command');
  $obj->send_to_gaia(@commands);

=cut


sub send_to_gaia {
  my $self = shift;

  croak 'Usage: send_to_gaia(commands)' unless @_;

  my @command = @_;
  my @results;
  my $command = '';
  my $num_commands = @command;
  print "length = $num_commands\n" if $DEBUG;
  my ($reply, $reply2, $result);
  my $message = '';
  foreach (@command) {
    $command .= "remotetcl \"$_\"\n";
  }
  print "command: $command\n" if $DEBUG;
  my $sock = $self->sock();
  print "prepping to send...\n" if $DEBUG;
  print $sock $command;
  print "completed send...\n" if $DEBUG;
  $message = '';
  for ( my $i = 0; $i < $num_commands; $i++ ) {
    $reply2 = '';
    print "prepping to receive...\n" if $DEBUG;
    my $a = '';
    $reply2 = '';
    while (!($reply2 =~ /[\n]/)) {
      recv ($sock, $reply2, 1, 0);
      $a.=$reply2;
    }
    $result = $a;
    print "completed receive...\n" if $DEBUG;
    print "i = $i.  results = $result\n" if $DEBUG;
    my ($start, $byte) = split / /, $result,2;
    while ($byte > 4096) {
      print "bytes are huge!!\n" if $DEBUG;
      recv ($sock, $reply2, 4096, 0); 
      $byte -=4096;
      $message .= $reply2;
    }
    print "prepping to receive\n" if $DEBUG;
    
    recv ($sock, $reply, $byte, 0);
    $message .= $reply;
    push (@results, $message);
    print "results received: $message\n" if $DEBUG;
    $message = '';
  }
  return ($results[0])  if ($num_commands < 2);
  return (@results);
}


=item image

Routine to display images in Gaia. Note that the full file name is required.
If an image name does not include an extension then '.sdf' is appended.
(ie NDF is assumed).

Takes a file name and arguments stored in a hash.

  $disp->image("filename", \%options)


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
  my $image = $self->send_to_gaia("$device get_image");

  # Just send to GAIA - configure the new file
  $self->send_to_gaia("$image configure -file $file");

  # Other options go here for dealing with ZAUTOSCALE etc


}

=back


=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu) and Casey Best (cbest@uvic.ca).

=cut


1;
