package ORAC::Display::KAPVIEW;

=head1 NAME

ORAC::Display::Kapview - ORACDR interface to Kapview (Kappa)

=head1 SYNOPSIS

=head1 DESCRIPTION

ORAC interface to Kappa Kapview. Provides methods for displaying images
and spectrum with Kapview.

Available options are:

IMAGE - display image using DISPLAY
GRAPH - display graph using LINPLOT
SIGMA - display scatter plot with a Y-range of +/-N sigma.

=cut

use 5.004;
use Carp;
use strict;

use ORAC::Msg::ADAM::Task;
use ORAC::Msg::ADAM::Control;

use File::Copy;
use Cwd;

use ORAC::Print;
use ORAC::Constants qw/:status/;        #  Constants

use vars qw/$VERSION $DEBUG $AGI_USER $AGI_NODE/;

$VERSION = '0.10';
$DEBUG = 0;

=head1 PUBLIC METHODS

=over 4

=item new

Object constructor. The constructor starts up a new version of kapview,
starts a GWM window and displays the startup logo.
undef is returned if the constructor fails (eg the ADAM message system
is not running).

The message system must be running so that Kapview can be configured.
(AMS is started if needed)

=cut


sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $disp = {};  # Anonymous hash

  $disp->{Obj} = undef;  # Messaging object
  $disp->{AMS} = undef;  # Adam message system storage
  $disp->{Dev} = {};     # Device list
  $disp->{Kappa} = undef; # Kappa_mon messaging object

  bless ($disp, $class);


  # Start message system (should just return if already started)
  my $status = ORAC__OK;
  # This check is a bit dodgy. I add it to stop the error message
  # occuring concerning whether the AMS is currently running or not.
  if ($ORAC::Msg::ADAM::Control::RUNNING == 0) {
    $disp->{AMS} = new ORAC::Msg::ADAM::Control;
    $status = $disp->{AMS}->init;
  } else {
    orac_print "AMS already running\n",'blue';
  }

  # Configure the AGI environment variables
  # Should tidy this up when we finish
  $ENV{AGI_USER} = "/tmp";
  $ENV{AGI_NODE} = "orac_kapview$$";

  # Store these values so that I know what file to remove 
  # independent of whether some other module has redefined them
  $AGI_USER = $ENV{AGI_USER};
  $AGI_NODE = $ENV{AGI_NODE};


  # Split the launching and configuration into separate subroutines
  if ($status == ORAC__OK) {
    $disp->launch;
    $status = $disp->configure;
  }

  # There has been an error launching kapview. We have no choice
  # but to die at this point since as soon as the current object
  # goes out of scope the kapview monolith will be killed.
  # The assumption is that if the kapview monolith had problems there
  # is no point keeping it around.
  # A related problem is that once we have tried to launch kapview 
  # (and managed to start a monolith the first time) the messaging
  # system never gets informed that the monolith died so next time
  # you try it the system thinks kapview is running and so doesn't launch
  # a new one. When you then try to contact anything you get a segmentation
  # fault because of the screwed message system.
  if ($status != ORAC__OK) {
    die "Error launching Kapview. It is unlikely that this can be fixed by retrying from within ORACDR. Please rerun either with the display switched off or with a different display device selected.";
  }
  
  return $disp;
}


=item obj

Messaging object associated with the Kapview display object.

=cut

sub obj {
  my $self = shift;
  if (@_) { $self->{Obj} = shift; }
  return $self->{Obj};
}

=item kappa

Messaging object associated with the kappa_mon monolith.
This is used by some of the modes in order to determine
display related values (eg statistics to determine plotting
ranges for SIGMA).

A kappa messaging object is created if the object is undefined.

=cut

sub kappa {
  my $self = shift;
  if (@_) { $self->{Kappa} = shift; }

  # Start kappa if needed
  unless (defined $self->{Kappa}) {
    orac_print ("Creating Kappa_mon object.............\n",'cyan') if $DEBUG;
    $self->{Kappa} = new ORAC::Msg::ADAM::Task("kappa_mon_$$", 
                              "$ENV{KAPPA_DIR}/kappa_mon"); 
  }

  return $self->{Kappa};
}


=item devref(\%hash)

Returns (or sets) the reference to the hash containing the current
mapping from display device to display window.

  $Display->devref(\%device);
  $hashref = $Display->devref

=cut

sub devref {
  my $self = shift;

  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Dev} = $arg;
  }
  return $self->{Dev};
}



=item display_devices(%hash)

Returns (or sets) a hash containing the current lookup of display device
to window.
For example:

   $Kap->display_devices(%devs);
   %devs = $Kap->display_devices;
 
where %tools could look like:

     '0' => 'xwindows;345_0xwin',
     '1' => 'xwindows;345_1xwin'

etc.

=cut

sub display_devices {
  my $self = shift;
  if (@_) {
    my %junk = @_;
    $self->devref(\%junk);
  }
  return %{$self->devref};
}


=item dev(win)

Returns the current display device associated with 'win'.
Returns undef if win does not exist.

=cut

sub dev {
  my $self = shift;
  my $win = shift;

  if (@_) {
    my $val = shift;
    $ {$self->devref}{$win} = $val;
  }
 
  if (exists $ {$self->devref}{$win} ) {
    return $ {$self->devref}{$win};
  } else {
    return undef;
  }

}


=item window_dev(win)

Returns the device id (in this case GWM device name)
associated with window win. If 'win' is undefined a new
GWM window is started, the id stored in the hash and the
new id returned. (see the launch_dev() method). If this
is the first time the routine is called (ie the only window
name present is 'default', the name of the default window
is associated with window win.). We go through this hoop
so that Kapview will open a window before we start plotting.

If the windows were launched with bad status we should 
set the device name to something recongnisable as bad!.

=cut

sub window_dev {
  my $self = shift;
  my $win = shift;
  my ($dev, $status);
  $status = ORAC__OK;

  # If the key exists already just return the value
  if (defined $self->dev($win)) {
    return $self->dev($win);
  }

  # Find out how many keys we have in the devices hash
  my $ndev = scalar keys %{$self->devref};

  # If there are zero keys (-1) we have to come up with a new name
  # if there is 1 key AND it is called 'default' then we need to return
  # this device and associate the new window with that device

  if ($ndev == 1) {
    # We already have a device open.
    # but this window does not map to it
    
    # If the 'default' exists then return that one and associate new
    # window with it
    if (defined $self->dev('default')){
      $self->dev($win, $self->dev('default'));
    } else {
      # get a new device and use that
      # New device
      $dev = $self->newdev($win);
      # Now set it in the object
      $self->dev($win, $dev);

      # and launch it...
      $status = $self->launch_dev($win);

    }  
  } else {
    # Need to create a new device
    # New device
    $dev = $self->newdev($win);
    # Now set it in the object
    $self->dev($win, $dev);

    # and launch it..
    # We do not trap the error...
    $status = $self->launch_dev($win);

  }


  return $self->dev($win);

}

=item newdev(win)

Given 'win', calculates a new device name that should be unique for
each 'win'.

=cut

sub newdev {
  my $self = shift;
  my $win = shift;
  
  my $dev = "xwindows;$$" . "$win" ."xwin";

  return $dev;
}


=item launch_dev(win)

Start the GWM window associated with the supplied window.
In general this is used by the startup configuration.
The lookup table is configured by this routine (so that
this routine really does start the GWM window).

Currently the GWM window itself is not started directly
by this routine (since KAPVIEW will automatically open
the specified device if one is not running).

The only reason to use this routine to actually START a window
is that it will give us some control over the colour allocation
and allow us to set the window name.

ORAC status is returned.

It may be simpler to just die() if the colour table 
setting fails (ie the device is no good to us).

=cut

sub launch_dev {
  my $self = shift;
  my $window = shift;

  # Get the device
  my $device = $self->window_dev($window);

  # If I want to start GWM myself I have to do the following
#  my $gwm = new Proc::Simple;
#  $gwm->start("gwm -colours 128 -gwmname $device -name \'ORACDR:P4 (${device}xwin)\'");
  # Pause so that GWM window can be contacted immediately
  # sleep 2;

  # The problem here is that if 'gwmname' matches an exisiting gwm
  # window then the gwm command crashes. This should be okay if  I
  # can hide the error message. Otherwise I need to check to see whether
  # the window is there beforehand (eg with the ps command)


  # Now every time we open a new device we need to configure
  # lookup table.
  # in general this means that the monolith must have started
  # and contact made
  # Load the colour table

  my $args = "mapping=linear coltab=external lut=$ENV{KAPPA_DIR}/bgyrw_lut";
  my $status = $self->obj->obeyw("lutable","$args device=$device");
  if ($status != ORAC__OK) {
    orac_err("Error configuring default LUT\n");
     die "Error launching display device. It is unlikely that this can be fixed by retrying from within ORACDR. Aborting...";
#    return $status;
  }

  # try a paldef
  my $status = $self->obj->obeyw("paldef","device=$device");
  if ($status != ORAC__OK) {
    orac_err("Error setting default pallette\n");
     die "Error launching display device. It is unlikely that this can be fixed by retrying from within ORACDR. Aborting...";
#    return $status;
  }


  return ORAC__OK;

}


=item launch

Launch kapview.

=cut

sub launch {
  my $self = shift;

  # Start kapview
  orac_print ("Starting KAPVIEW........................\n",'cyan') if $DEBUG;
  my $display = new ORAC::Msg::ADAM::Task("kapview_mon_$$", "$ENV{KAPPA_DIR}/kapview_mon"); 

  # Store the object
  $self->obj($display);

}


=item configure

Load a startup image.

=cut

sub configure {
  my $self = shift;

  my $status;

  # Now try to contact the kapview monolith (this will cause trouble
  # if AMS is not running.

  my $contact =$self->obj->contactw;         # ensure contact is made
  unless ($contact) {
    orac_err("Unable to contact Display (kapview) before timeout");
    return $status;
  }

  # open the GWM window
  # and configure the lookup table
#  $status = $self->launch_dev('default');
#  return $status unless $status == ORAC__OK; 

  my $startup = "$ENV{ORAC_DIR}/images/orac_start";

  # Set the device for port_0 for our default display
  my $device = $self->window_dev('default');

  # Replace $ with \$ for eval during obeyw()
  my $data = $startup;
  $data =~ s/\$/\\\$/g;  
 
  # Configure port 0
  $device = $self->config_region( WINDOW=>'default',REGION=>0);
  unless (defined $device) {
    orac_err("Error configuring display. Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Ask Kapview to display
  $status = $self->obj->resetpars;
  $status = $self->obj->obeyw("display", "in=$data mode=sc device=$device accept");
  if ($status != ORAC__OK) {
    orac_err("Error displaying startup image\n");
    orac_err("Trying to execute: display in=$data\n");
  }
 
  return $status;
  
}


=item config_region

This method configures the display regions.

  $device = $self->process_options(%opt);

Returns undef without action if the REGION keyword is not available (since
this is the port number) or if REGION is not in the allowed range.
Otherwise the actual modified device name is returned.
undef is returned if no arguments are supplied.

If the window name is not supplied (WINDOW) then 'default' is assumed.

=cut

sub config_region {
  my $self = shift;

  return undef unless @_;

  my %options = @_;

  my $port = undef;

  if (exists $options{REGION}) {
    $port = $options{REGION};
    orac_print("Port is $port\n",'cyan') if $DEBUG;
    # Port must be an integer between 0 and 8
    return undef unless ($port =~ /^[0-8]$/);

  } else {
    return undef;
  }


  # Find the Window name
  my $window = 'default';
  if (exists $options{WINDOW}) {
    $window = $options{WINDOW};
  }
  # and convert it into a device id
  my $device = $self->window_dev($window);

  # We now have a device and port number

  # Construct the string that we send to PICDEF
  my $string;

  my @regions = (
		 "cc [1,1]",
		 "tl", "tr", "bl","br",
		 "cl [0.5,1.0]", "cr [0.5,1.0]",
		 "tl [1.0,0.5]", "bl [1.0,0.5]"
		);

  # Set the string
  $string = $regions[$port];

  print "Configuring region $port with $string\n";
  # Configure with PICDEF
  my $status = $self->obj->obeyw("picdef","device=$device nocurrent outline $string");
  
  if ($status != ORAC__OK) {
    orac_err("Error configuring region\n");
    return undef;
  }

  return $device;

}

=item image

Display an image.
Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

=cut

sub image {

  my $self = shift;
 
  my $file = shift;

  my $opt;
  my %options = ();
  if (@_) {
    $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->config_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display. Possible invalid region designation\n");
    return ORAC__ERROR;
  }


  # Options handling can not be taken out into a sub since every
  # kapview command has subtly different parameter names,

  # Construct the parameter string for DISPLAY
  my $optstring = " ";

  # Set default scaling
  $optstring .= " mode=scale ";
  # Autoscaling is a special case
  if (exists $options{AUTOSCALE}) {
    # Kappa display can autoscale if required
    # Using MODE=SCALE
    
    if ($options{AUTOSCALE} == 0) {
      # We are specifying a min and max
      $optstring .= " low=$options{MIN} " if exists $options{MIN};
      $optstring .= " high=$options{MAX} " if exists $options{MAX};

    }
  }

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf
  
  my $status;

  # Get weird errors without the resetpars:
  #!! HDS locator invalid: value=' ', length=15 (possible programming error).
  #!  DAT_CLONE: Error cloning (duplicating) an HDS locator.
  #!  DAT__LOCIN, Locator invalid
  #MODE -- Method to define the scaling limits / 'sc' / > 
 
  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;
  
  # Do the obeyw
  $status = $self->obj->obeyw("display", "device=$device in=$file axes clear $optstring accept");
  if ($status != ORAC__OK) {
    orac_err("Error displaying image\n");
    orac_err("Trying to execute: display device=$device axes in=$file\n");
  }
  return $status;

}

=item graph

Display a 1-D plot.

Currently the data input must be 1-D.

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

=cut

sub graph {

  my $self = shift;
 
  my $file = shift;

  my %options = ();
  if (@_) {
    my $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->config_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display. Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  my $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;


  # Should probably set the options
  # If we are autoscaling then we dont need any axis setting
  # default is not to send any axis control information
  my $range;
  if (exists $options{AUTOSCALE}) {
    if ($options{AUTOSCALE}) {
      $range = "axlim=false";
    } else {
      # Set the Y range
      my $min = 0;
      my $max = 0;
      $min = $options{LOW} if exists $options{LOW};
      $max = $options{HIGH} if exists $options{HIGH};
      $range = "axlim=true abslim=! ordlim=[$min,$max]";
    }
  }

  # Construct string for linplot options
  my $args = "clear mode=line $range";

  # Run linplot
  $status = $self->obj->obeyw("linplot","ndf=$file(1,) device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error displaying graph\n");
    orac_err("Trying to execute: linplot ndf=$file device=$device $args$\n");
    return $status;
  }

  return $status;


}


=item sigma

Display a scatter plot of the data with Y range of N-sigma (sigma
is derived from the data) with dashed lines overlaid at the X-sigma
points.

By default a range of +/-5 sigma with dashed lines at +/-3 sigma
are used.

These values can be overriden by using the RANGE and DASHED 
keywords.

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

=cut

sub sigma {

  my $self = shift;
 
  my $file = shift;

  my %options = ();
  if (@_) {
    my $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->config_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display. Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # Probably should try to find out whether the array is 1 or 2 dimensional
  # since currently linplot fails if the data is not 1-D
  # would have to use NDFTRACE from NDFPACK OR use my NDF module
  # to do it directly
  # Cant be bothered at the moment...

  # First thing to do is calculate the relevant statistics of the
  # input file.
  # Use kappa STATS
  my $status;
  if ($self->kappa->contactw) {
    $status = $self->kappa->obeyw("stats","ndf=$file");
    if ($status != ORAC__OK) {
      orac_err("Error calculating statistics of data file\n");
      return $status;
    }
  } else {
    orac_err("Error contacting Kappa_mon\n");
    return ORAC__ERROR
  }

  # Now retrieve the answer
  my ($mean, $sigma);
  ($status,  $mean) = $self->kappa->get("stats","mean");
  ($status, $sigma) = $self->kappa->get("stats","sigma");


  # Now need to check the options string
  my $range = 5.0;
  my $dashed = 3.0;

  $range = $options{RANGE} if (exists $options{RANGE});
  $dashed = $options{DASHED} if (exists $options{DASHED});

  # Now calculate the range of the plot
  my $max = $mean + ($range * $sigma);
  my $min = $mean - ($range * $sigma);

  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;

  # Construct string for linplot options
  my $args = "clear mode=2 axlim=true ordlim=[$min,$max] abslim=!";

  # Run linplot
  $status = $self->obj->obeyw("linplot","ndf=$file device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error displaying sigma plot\n");
    orac_err("Trying to execute: linplot ndf=$file device=$device $args$\n");
    return $status;
  }

 
  # Run drawsig
  $args = "linestyle=2 sigcol=red nsigma=[0,$dashed]";
  $status = $self->obj->obeyw("drawsig","device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error overlaying lines\n");
    orac_err("Trying to execute: drawsig device=$device $args$\n");
    return $status;
  }

  return $status;
}


# DESTROY
# Remove the AGI file when we have finished with kapview

sub DESTROY {
   my $self = shift;
  
   # Construct the name of the AGI file
   my $fname = $AGI_USER . "/agi_" . $AGI_NODE . ".sdf";
   
   # Remove it
   unlink($fname);

}




=back
 
=head1 SEE ALSO

L<ORAC::Display>, L<ORAC::Display::GAIA>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=cut





1;



