package ORAC::Display::KAPVIEW;

=head1 NAME

ORAC::Display::KAPVIEW - ORACDR interface to Kapview (Kappa)

=head1 SYNOPSIS

  use ORAC::Display::KAPVIEW;
  $disp = new ORAC::Display::KAPVIEW;

  $disp->image($file, { XAUTOSCALE => 1});

=head1 DESCRIPTION

ORAC interface to Kappa Kapview. Provides methods for displaying images
and spectrum with Kapview.

Available options are:

IMAGE - display image using DISPLAY
GRAPH - display graph using LINPLOT
SIGMA - display scatter plot with a Y-range of +/- N sigma.
DATAMODEL - Display data (as points) with a model overlaid
HISTOGRAM - Histogram of values in data array

=cut

use 5.004;
use Carp;
use strict;

use ORAC::Msg::ADAM::Task;
use ORAC::Msg::ADAM::Control;

use File::Copy;
use Cwd;

use NDF;  # To read image bounds

use ORAC::Print;
use ORAC::Constants qw/:status/;        #  Constants
use ORAC::General;                      # Max and min

use base qw/ ORAC::Display::Base /;     # Base class

use vars qw/$VERSION $DEBUG $AGI_USER $AGI_NODE/;

$VERSION = '0.10';
$DEBUG = 0;

=head1 PUBLIC METHODS

=over 4

=item new

Object constructor. The constructor starts up a new version of kapview,
starts a GWM window and displays the startup logo.

The program aborts if there is an error launching kapview.

The message system must be running so that Kapview can be configured.
(AMS is started if needed)

=cut


sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create a new instance from the base class
  my $disp = $class->SUPER::new(Obj => undef,    # Messaging object
				AMS => undef,    # Adam message system
				Kappa => undef  # Kappa_mon object
			       );

  # Start message system (should just return if already started)
  my $status = ORAC__OK;
  $disp->{AMS} = new ORAC::Msg::ADAM::Control;
  $status = $disp->{AMS}->init;

  # Configure the AGI environment variables
  # Should tidy this up when we finish
  BEGIN { # A kluge - for some reason kapview does not pick up the
          # correct environment if I leave out the BEGIN block
          # dont understand since the environment is passed to the forked
          # process...
    $ENV{'AGI_USER'} = "/tmp";
    $ENV{'AGI_NODE'} = "orac_kapview$$";
  }

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

Note also that the HISTOGRAM task is present in the kappa monolith
rather than in the KAPVIEW monolith.

=cut

sub kappa {
  my $self = shift;
  if (@_) { $self->{Kappa} = shift; }

  # Start kappa if needed
  unless (defined $self->{Kappa}) {
    orac_print ("Creating Kappa_mon object.............\n",'cyan') if $DEBUG;

    # Note that a MONOLITH name is supplied as an option.
    # This is so that if a path to the monolith exists and it
    # is an A-task [note that we dont specify task type - if a
    # kappa monolith is already running on this path as an I-task
    # then parameter retrieval will fail. It is possible that in the
    # future the objects will be stored so that if a monolith is started
    # by the same process in a different piece of code a copy of the
    # task object will be returned rather than creating a new one.)
    # Currently this is still a bit of a kluge and requires some knowledge
    # of the way that the kappa monolith used by the recipes was started.
    $self->{Kappa} = new ORAC::Msg::ADAM::Task("kappa_mon_$$", 
					       "$ENV{KAPPA_DIR}/kappa_mon",
					       { MONOLITH => 'kappa_mon' }
					      ); 
  }

  return $self->{Kappa};
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


=item create_dev(win)

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

sub create_dev {
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

This method starts the kapview monolith and stores the associated
Task object.

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

Load a startup image. This tests the system to make sure that images
can be displayed and that the colour map is loaded.

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
#  $status = $self->create_dev('default');
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

  $device = $self->config_region(%opt);

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

  orac_print("Configuring AGI region $port with $string\n",'cyan') if $DEBUG;
  # Configure with PICDEF
  my $status = $self->obj->obeyw("picdef","device=$device nocurrent outline $string");
  
  if ($status != ORAC__OK) {
    orac_err("Error configuring region\n");
    return undef;
  }

  return $device;

}

=item select_section

This method converts a file name and options hash into
a filename with an attached NDF section.

  $newfile = $Display->select_section($file, \%options, $dimensionality);

An optional 3rd argument can be used to specify the required 
dimensionality. If the number of dimensions in the data file is
greater than that requested, sections in higher dimensions
are set to 1 (with the assumption that KAPPA will discard axes
with 1 pixel). If the number of dimensions in the data file
is fewer than that requested, a warning message is printed
but we continue in the hope that KAPPA will work something out....

The return value is the original filename with the
NDF section attached.

Relevant keywords in options hash:

  XMIN/XMAX - X pixel max and min values
  YMIN/YMAX - Y pixel max and min values
  XAUTOSCALE - Use autoscaling for X?
  YAUTOSCALE - Use autoscaling for Y?

If Xautoscale and Yautoscale are true, no section command is appended.
If the XAUTOSCALE/YAUTOSCALE/nAUTOSCALE keywords can not be found they are
assumed to be true.

For data arrays with N>2, the leading letter is dropped and replaced
by the dimension number. eg:

  3MIN/3MAX - pixel range of the 3rd dimension
  4AUTOSCALE - autoscale the 4th dimension?

For NDFs the maximum dimensionality is 7.

The bounds of the input file are compared to the supplied bounds.
If any of the requested bounds are exceeded, the maximum value
will be used instead. 

Returns undef on error.
The unmodified file name is returned if no options hash can be found.

=cut


sub select_section {
  my $self = shift;
  my $file = shift;
  my $options = shift;

  return $file if ref($options) ne 'HASH';

  # Maximum number of allowed dimensions for an NDF
  my $maxdim = 7;  

  # Read the dimensionality (default to 7)
  my $max_requested = $maxdim;
  $max_requested = shift if @_;

  # Take a copy of the options hash
  my %options = %{$options};

  # Define lookup table of prefix (allow up to 7 dimensions)
  my @lookup = ( "X", "Y", 3..$maxdim);
  my @autosc = ();  # Autoscale flags
  my $auto_all = 1; # Flag to keep track of global autoscale
 
  # Read the autoscale flags from the hash
  for my $dim (@lookup) {
    my $autosc = 1;
    my $key = $dim . "AUTOSCALE";
    $autosc = $options{$key} if exists $options{$key};
    push (@autosc, $autosc);

    # Set flag to 0 if any of the autoscale flags are false
    $auto_all = 0 unless $autosc; 
  }

  # Now query the file for its bounds to make sure that the pixel
  # index bounds supplied to not exceed the bounds of the file
  # Could do this by opening the file using NDF or by using the
  # KAPPA ndftrace command. Doing it myself has less overhead
  # (and will use fewer lines!!)

  my $status = &NDF::SAI__OK;
  my ($indf, @lbnd, @ubnd, $ndim);
  ndf_find(&NDF::DAT__ROOT, $file, $indf, $status);
  ndf_bound($indf, 7, @lbnd, @ubnd, $ndim, $status);
  ndf_annul($indf, $status);
  if ($status != &NDF::SAI__OK) {
    err_annul($status);
    orac_err("Error reading bounds from input file: $file");
    return undef;
  }

  # Return the filename if all the autoscale flags are true
  # and the dimensionality does not exceed to maximum requested
  # (Else we will have to generate a section
  return $file if ($auto_all && $ndim <= $max_requested);

  
#  print "Ndims = $ndim\n";
#  print "Lower bounds are: ", join(":",@lbnd),"\n";
#  print "Upper bounds are: ", join(":",@ubnd),"\n";

  # This is an array describing the section for each dimension
  my @sects = ();

  # Loop over all valid dimensions
  for my $dim (1..$ndim) {
    my $index = $dim-1;

    # If dim is greater than max_requested - set section to 1
    if ($dim > $max_requested) {
      $sects[$index] = 1;
      next;
    }

    # Check that this dim is mentioned in the lookup table
    if (defined $lookup[$index]) {

      # Check the autoscale flag for this dim
      unless ($autosc[$index]) {

	# Read the bounds from the hash
	my $pre = $lookup[$index];

	# Lower bound is minimum of $lbnd[$dim-1] and $options{?MIN}
        my $lower = max($lbnd[$index], $options{"${pre}MIN"});
        my $upper = min($ubnd[$index], $options{"${pre}MAX"});

	$sects[$index] = "$lower:$upper";

      } else {
        # An empty section
	$sects[$index] = undef;
      }

    }

  }  
  
  # Construct the section
  my $section = "(". join(",", @sects) . ")";

  # Return the filename
  return "$file$section";

}

=back

=head1 DISPLAY METHODS

=over 4

=cut

######################## DISPLAY MODES ##############################

=item image

Display an image.
Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

Recognised options:

  XMIN/XMAX - X pixel max and min values
  YMIN/YMAX - Y pixel max and min values
  XAUTOSCALE - Use autoscaling for X?
  YAUTOSCALE - Use autoscaling for Y?
  ZMIN/ZMAX  - Z-range of greyscale (data units)
  ZAUTOSCALE - Autoscale Z?

Default is to autoscale.

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

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # Calculate NDF section
  $file = $self->select_section($file,\%options,2);

  # Construct the parameter string for DISPLAY
  my $optstring = " ";

  # Set default scaling
  $optstring .= " mode=scale ";
  # Autoscaling is a special case
  if (exists $options{ZAUTOSCALE}) {
    # Kappa display can autoscale if required
    # Using MODE=SCALE
    
    if ($options{ZAUTOSCALE} == 0) {
      # We are specifying a min and max
      $optstring .= " low=$options{ZMIN} " if exists $options{ZMIN};
      $optstring .= " high=$options{ZMAX} " if exists $options{ZMAX};

    }
  }

  
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

If the data are not 1-D, a section is taken that assures
1-D (eg NDF section= :,1,1,1 for 4D data)

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

Display keywords:

  XMIN/XMAX  - X-pixel range of graph
  XAUTOSCALE - Autoscale pixel range?
  YMIN/YMAX  - Y-range of graph (in data units)
  YAUTOSCALE - Autoscale Y-axis
  COMP       - Component to display (Data (default), or Error)

Default is to autoscale.

Need to add way of controlling line style (eg replace with symbols)

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

  # Calculate the NDF section
  $file = $self->select_section($file,\%options,1);

  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  my $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;


  # Should probably set the options
  # If we are autoscaling then we dont need any axis setting
  # default is not to send any axis control information
  my $range;
  if (exists $options{YAUTOSCALE}) {
    if ($options{YAUTOSCALE}) {
      $range = "axlim=false";
    } else {
      # Set the Y range
      my $min = 0;
      my $max = 0;
      $min = $options{YMIN} if exists $options{YMIN};
      $max = $options{YMAX} if exists $options{YMAX};
      $range = "axlim=true abslim=! ordlim=[$min,$max]";
    }
  }

  # Construct string for linplot options
  my $args = "clear mode=line $range";

  # Select component
  if (exists $options{COMP}) {
    $args .= " COMP=$options{COMP}";
  }


  # Run linplot
  $status = $self->obj->obeyw("linplot","ndf=$file device=$device $args reset");
  if ($status != ORAC__OK) {
    orac_err("Error displaying graph\n");
    orac_err("Trying to execute: linplot ndf=$file device=$device $args\n");
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

MAY WANT TO CONERT THE NDF INTO 1-D BEFORE PLOTTING
(SINCE WE ARE ONLY INTERESTED IN THE SCATTER)
KAPPA 0.13 HAS A RESHAPE COMMAND - put this in when I upgrade
to 0.13.

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
  if ($status != ORAC__OK) {
    orac_err "Error in ORAC::Display::KAPVIEW::sigma\n";
    orac_err("Error retrieving value of parameter MEAN from Kappa task STATS\n");
    return $status;
  }

  ($status, $sigma) = $self->kappa->get("stats","sigma");
  if ($status != ORAC__OK) {
    orac_err "Error in ORAC::Display::KAPVIEW::sigma\n";
    orac_err("Error retrieving value of parameter SIGMA from Kappa task STATS\n");
    return $status;
  }


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
  # regions are not picked up correctly. This may be fixed when 
  # running as an A-task rather than an I-task.

  $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;

  # Construct string for linplot options
  my $args = "clear mode=2 axlim=true ordlim=[$min,$max] abslim=!";

  # Run linplot
  $status = $self->obj->obeyw("linplot","ndf=$file device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error displaying sigma plot\n");
    orac_err("Trying to execute: linplot ndf=$file device=$device $args\n");
    return $status;
  }

 
  # Run drawsig
  $args = "linestyle=2 sigcol=red nsigma=[0,$dashed]";
  $status = $self->obj->obeyw("drawsig","device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error overlaying lines\n");
    orac_err("Trying to execute: drawsig device=$device $args\n");
    return $status;
  }

  return $status;
}


=item datamodel

Display mode where the supplied filename is plotted as individual
points and a model is overlaid as a solid line. This can be used
to determine the goodness of fit of data and model.

The model filename is derived from the input filename (a _model
extension is expected). The data is displayed if the model
file can not be found.

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

Option keywords:

  XMIN/XMAX  - X-pixel range of graph
  XAUTOSCALE - Autoscale pixel range?
  YMIN/YMAX  - Y-range of graph (in data units)
  YAUTOSCALE - Autoscale Y-axis

Default is to autoscale on the data (the model may not be visible).

If the input file is greater than 1-D, the section is automatically
converted to 1-D by selecting the 1 slice from each of the
higher axes

=cut

sub datamodel {

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

  # Calculate NDF section
  $file = $self->select_section($file,\%options,1);

  # Probably should try to find out whether the array is 1 or 2 dimensional
  # since currently linplot fails if the data is not 1-D
  # would have to use NDFTRACE from NDFPACK OR use my NDF module
  # to do it directly
  # Cant be bothered at the moment...
    
  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  my $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;

  # Now plot the data
  my $args = "clear mode=2 symcol=white axlim=false";
  $status = $self->obj->obeyw("linplot","ndf=$file device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error displaying data file\n");
    orac_err("Trying to execute: linplot ndf=$file device=$device $args\n");
    return $status;
  }

  # Now plot overlay the model if it is available
  my $model = $file . "_model";

  # Calculate the NDF section of the model
  $model = $self->select_section($model,\%options,1);

  if (-e $model . ".sdf") {  # Assume .sdf extension!!!!

    # Construct the arguments
    $args = "noclear mode=line lincol=red pltitl='' ordlab=''";

    # Run linplot
    $status = $self->obj->obeyw("linplot","ndf=$model device=$device $args");
    if ($status != ORAC__OK) {
      orac_err("Error overlaying model\n");
      orac_err("Trying to execute: linplot ndf=$model device=$device $args\n");
      return $status;
    }
  }


}


=item histogram

Display a histogram of the data values present in the 
data array.

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

Arguments:

  XMIN/MAX - minimum/maximum x-pixel value
  XAUTOSCALE - Use full X-range
  YMIN/YMAX - minimum/maximum x-pixel value
  YAUTOSCALE - use full Y-range
  ZMIN/ZMAX - Z range of histogram (data units)
  ZAUTOSCALE - use full Z-range
  NBINS - Number of bins to be used for histogram calculation

Default is for autoscaling and for NBINS=20.

=cut

sub histogram {

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

  # Calculate NDF section
  $file = $self->select_section($file,\%options);

  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.
  # May not be necessary if KAPVIEW is an A-task

  my $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;


  # THIS IS THE HISTOGRAM SPECIFIC STUFF

  # Should probably set the options
  # If we are autoscaling then we dont need any axis setting
  # default is not to send any axis control information
  # Just do Z-range for now

  my $range = "range=!";
  if (exists $options{ZAUTOSCALE}) {
    if ($options{ZAUTOSCALE}) {
      $range = "range=!";
    } else {
      # Set the Y range
      my $min = 0;
      my $max = 0;
      $min = $options{ZMIN} if exists $options{ZMIN};
      $max = $options{ZMAX} if exists $options{ZMAX};
      $range = "range=[$min,$max]";
    }
  }
  my $nbins = " NUMBIN=20";
  $nbins = " NUMBIN=$options{NBINS}" if exists $options{NBINS};

  # Construct string for linplot options
  my $args = "$range $nbins";

  # Run histogram
  $status = $self->kappa->obeyw("histogram","in=$file device=$device $args accept");
  if ($status != ORAC__OK) {
    orac_err("Error displaying histogram\n");
    orac_err("Trying to execute: histogram ndf=$file device=$device $args accept\n");
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



