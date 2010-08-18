package ORAC::Display::P4;

=head1 NAME

ORAC::Display::P4 - ORACDR interface to P4

=head1 SYNOPSIS

  use ORAC::Display::P4;

  $disp = new ORAC::Display::P4;

  $disp->image($file);

=head1 DESCRIPTION

ORAC interface to P4. Provides methods for displaying images
and spectrum with P4.

Supported display modes:

  IMAGE - display 2-d image
  SURFACE - display 3-d surface of 2-d image
  CONTOUR - display contour plot
  HISTOGRAM - display data histogram
  OVERGRAPH - display graph without clearing display

=cut

use 5.004;
use Carp;
use strict;

use Starlink::NBS;

use File::Copy;
use Cwd;

use ORAC::Print;
use ORAC::Constants qw/:status/;        #  Constants
use ORAC::Msg::EngineLaunch;

use base qw/ ORAC::Display::Base /;     # Base class

use vars qw/$VERSION $DEBUG/;

$VERSION = '1.0';
$DEBUG = 0;

=head1 PUBLIC METHODS

=head2 Constructor

=over 4

=item B<new>

Object constructor. The constructor starts up a new version of P4 and
configures the default noticeboard, starts a GWM window and displays
the startup logo.
undef is returned if the constructor failes (eg the ADAM message system
is not running).

The message system must be running so that P4 can be configured.
(The constructor attempts to start the message system itself)

=cut


sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

 # Create a new instance from the base class
  my $disp = $class->SUPER::new(Obj => undef,    # Messaging object
				EngineLaunch => new ORAC::Msg::EngineLaunch,
				NBS => undef     # Notice board location
			       );

  my $status = ORAC__OK;
  # Split the launching and configuration into separate subroutines

  if ($status == ORAC__OK) {
    $disp->launch;
    # Check that P4 was launched
    if ( defined $disp->{Obj}) {
      $status = $disp->configure;
    } else {
      $status = ORAC__ERROR;
    }
  }

  # There has been an error launching P4. We have no choice
  # but to die at this point since as soon as the current object
  # goes out of scope the P4 monolith will be killed.
  # The assumption is that if the P4 monolith had problems there
  # is no point keeping it around.
  # A related problem is that once we have tried to launch P4
  # (and managed to start a monolith the first time) the messaging
  # system never gets informed that the monolith died so next time
  # you try it the system thinks P4 is running and so doesn't launch
  # a new one. When you then try to contact anything you get a segmentation
  # fault because of the screwed message system.
  if ($status != ORAC__OK) {
    die "Error launching P4. It is unlikely that this can be fixed by retrying from within ORACDR. Please rerun either with the display switched off or with a different display device selected.";
  }

  return $disp;
}


=back

=head2 Accessor Methods

=over 4

=item B<engine_launch_object>

Returns the C<ORAC::Msg::EngineLaunch> object that can be used
to launch algorithm engines as required by the particular
conversion.

 $messys = $self->messys_launch_object;

=cut

sub engine_launch_object {
  my $self = shift;
  return $self->{EngineLaunch};
}

=item B<obj>

Messaging object associated with the P4 display object.

=cut

sub obj {
  my $self = shift;
  if (@_) { $self->{Obj} = shift; }
  return $self->{Obj};
}

=item B<nbs>

The noticeboard object associated with the P4 object.

=cut

sub nbs {
  my $self = shift;
  if (@_) { $self->{NBS} = shift; }
  return $self->{NBS};
}


=back

=head2 General Methods

=over 4

=item B<newdev>

Given 'win', calculates a new device name that should be unique for
each 'win'.

  $name = $p4->newdev($win);

=cut

sub newdev {
  my $self = shift;
  my $win = shift;

  my $dev = "xwindows;$$" . "$win" ."xwin";

}


=item B<create_dev>

Start the GWM window associated with the supplied window.
In general this is used by the startup configuration.
The lookup table is configured by this routine (so that
this routine really does start the GWM window).

Currently the GWM window itself is not started directly
by this routine (since P4 will automatically open
the specified device if one is not running).

The only reason to use this routine to actually START a window
is that it will give us some control over the colour allocation
and allow us to set the window name.

  $status = $p4->create_dev($win);

ORAC status is returned.

It may be simpler to just die() if the colour table
setting fails (ie the device is no good to us).


=cut

sub create_dev {
  my $self = shift;
  my $window = shift;


  my $device = $self->window_dev($window);

  # Set the device for port_0 for our default display
  $self->nbs->poke(".port_0.device_name", "$device");

  # Now every time we open a new device we need to configure
  # lookup table.
  # in general this means that the monolith must have started
  # and contact made
  # Load the colour table

  # Load the colour table and plot the ramp
  my $status = $self->obj->obeyw("lut","port=0");
  if ($status != ORAC__OK) {
    orac_err("Error configuring default LUT\n");
#    return $status;
     die "Error launching display device. It is unlikely that this can be fixed by retrying from within ORACDR. Aborting...";

  }

  return ORAC__OK;

}


=item B<launch>

Set up P4 environment variables, launch a P4 process

=cut

sub launch {
  my $self = shift;

  # Start P4
  orac_print("Starting P4.............................\n",'cyan') if $DEBUG;

  my $display = $self->engine_launch_object->engine("p4");

  # Store the object
  $self->obj($display) if defined $display;
  return;
}


=item B<configure>

Configure the notice board and open the start up image

=cut

sub configure {
  my $self = shift;

  my $status;

  # Come up with a noticeboard name

  my $toolpid = $self->obj->pid;
  $toolpid = scalar reverse ($toolpid);
  my $nbsname = "p".$toolpid. "_plotnb";

  # Now try to contact the p4 monolith (this will cause trouble
  # if AMS is not running.

  my $contact =$self->obj->contactw;         # ensure contact is made
  unless ($contact) {
    orac_err("Unable to contact Display (P4) before timeout");
    return $status;
  }

  # Now configure the noticeboard
  orac_print("Configuring P4 NBS ($nbsname)...",'blue');

  $status = $self->obj->obeyw("open_nb","noticeboard=$nbsname reset");
  if ($status != ORAC__OK) {
    orac_err ("Error opening noticeboard\n");
    return $status;
  }

  $status = $self->obj->obeyw("restore","file=$ENV{P4_CONFIG}/default.p4 port=-1");
  if ($status != ORAC__OK) {
    orac_err("Error configuring noticeboard\n");
    return $status;
  }

  # Print completion message
  orac_print("Done\n",'blue');

  # Open local version of noticeboard
  my $Nbs = new Starlink::NBS ($nbsname);

  # Check notice board status
  unless ($Nbs->isokay) {
    orac_err("Error opening noticeboard\n");
    return ORAC__ERROR;
  }

  # Store the noticeboard object in the object
  $self->nbs($Nbs);

  # Set some local values

  my $startup = '$ORAC_DIR/images/orac_start';
  $Nbs->poke(".port_0.display_type", "IMAGE");
  $Nbs->poke(".port_0.display_data", "$startup");
  $Nbs->poke(".port_1.display_data", '$P4_CT/cgs4');
  $Nbs->poke(".port_2.display_data", '$P4_CT/cgs4');
  $Nbs->poke(".port_3.display_data", '$P4_CT/cgs4');
  $Nbs->poke(".port_4.display_data", '$P4_CT/cgs4');
  $Nbs->poke(".port_5.display_data", '$P4_CT/cgs4');
  $Nbs->poke(".port_6.display_data", '$P4_CT/cgs4');
  $Nbs->poke(".port_7.display_data", '$P4_CT/cgs4');
  $Nbs->poke(".port_8.display_data", '$P4_CT/cgs4');
  $Nbs->poke(".port_0.title", "");
  $Nbs->poke(".port_0.plot_axes","0");

  # Set the device for port_0 for our default display
  # This will trigger a launch of the display and
  # setting of the LUT.
  my $device = $self->window_dev('default');
  $Nbs->poke(".port_0.device_name", "$device");


  # Load the colour table and plot the ramp
#  $status = $self->obj->obeyw("lut","port=0");
#  if ($status != ORAC__OK) {
#    orac_err("Error configuring default LUT\n");
#    return $status;
#  }


  my ($data) = $Nbs->peek(".port_0.display_data");  # We know what this is!

  # Check for possible corruption of noticeboard
  $data =~ s/\s+$//;  # Remove trailing space
  if ($data ne $startup) {
    orac_err("Error reading startup image name from noticeboard\n");
    orac_err("Expected $startup but received $data\n");
    orac_err("P4 noticeboard could be corrupt. Continuing...\n");
    $data = $startup;
  }

  # Replace $ with \$ for eval during obeyw()
  $data =~ s/\$/\\\$/g;

  # Ask P4 to display
  # This could be done by the 'image' method...

  $status = $self->obj->obeyw("display", "data=$data");
  if ($status != ORAC__OK) {
    orac_err("Error displaying startup image\n");
    orac_err("Trying to execute: display data=$data\n");
  }

  $status = $self->obj->obeyw("status");
  if ($status != ORAC__OK) {
    orac_err("Error determining P4 status\n");
  }

  # Put axes back on the plot
  $Nbs->poke(".port_0.plot_axes", "1");

  return $status;

}


=item B<process_options>

This method parses the options hash and configures the P4 noticeboard
to reflect the settings

It does not configure the display_type.

  $port = $self->process_options(%opt);

Returns undef without action if the REGION keyword is not available (since
this is the port number) or if REGION is not in the allowed range.
Otherwise the actual port number is returned.
undef is returned if no arguments are supplied.

Valid keywords:

  ZAUTOSCALE
  ZMIN
  ZMAX
  NBINS
  NCONT
  CONTTYPE

If the window name is not supplied (WINDOW) then 'default' is assumed.

=cut

sub process_options {
  my $self = shift;

  return unless @_;

  my %options = @_;

  my $port = undef;

  if (exists $options{REGION}) {
    $port = $options{REGION};
    orac_print("Port is $port\n",'cyan') if $DEBUG;
    # Port must be an integer between 0 and 8
    return unless ($port =~ /^[0-8]$/);

  } else {
    return;
  }


  # Find the Window name
  my $window = 'default';
  if (exists $options{WINDOW}) {
    $window = $options{WINDOW};
  }
  # and convert it into a device id
  my $device = $self->window_dev($window);


  # Okay so we now have a valid port number
  # construct the noticeboard entry
  my $nbs_name = ".port_$port";

  # Get a tied hash
  my $lnbs = $self->nbs->find($nbs_name);
  my $href = $lnbs->tienbs;

  return unless defined $href;

  # Configure the device name of the current port
  my $status;

  $$href{"device_name"} = $device;

  # Need to loop over the options keys
  foreach my $key (keys %options) {

    # Dont worry about WINDOW or REGION
    next if $key eq "WINDOW";
    next if $key eq "REGION";
    next if $key eq "TOOL";
    next if $key eq "TYPE";

    orac_print("Setting $key to $options{$key}\n",'cyan') if $DEBUG;
    $key eq 'ZAUTOSCALE' && ($$href{'AUTOSCALE'} = $options{ZAUTOSCALE});
    $key eq 'ZMIN'       && ($$href{'LOW'} = $options{ZMIN});
    $key eq 'ZMAX'       && ($$href{'HIGH'} = $options{ZMAX});
    $key eq 'NBINS'  && ($$href{'HISTOGRAM_BINS'} = $options{NBINS});
    $key eq 'HISTXSTEP' && ($$href{'HISTOGRAM_XSTEP'} = $options{HISTXSTEP});
    $key eq 'HISTYSTEP' && ($$href{'HISTOGRAM_YSTEP'} = $options{HISTYSTEP});
    $key eq 'HISTSMOOTH' && ($$href{'HIST_SMOOTH'} = $options{HISTSMOOTH});
    $key eq 'CUT'       && ($$href{'CUT_DIRECTION'} = $options{CUT});
    $key eq 'ERR'       && ($$href{'PLOT_ERRORS'} = $options{ERR});
    $key eq 'SLC_START' && ($$href{'SLICE_START'} = $options{SLC_START});
    $key eq 'SLC_END' && ($$href{'SLICE_END'} = $options{SLC_END});
    $key eq 'OVERCOL' && ($$href{'OVERCOLOUR'} = $options{OVERCOL});
    $key eq 'NCONT'   && ($$href{'CONTOUR_LEVELS'} = $options{NCONT});
    $key eq 'CONTTYPE' && ($$href{'CONTOUR_TYPE'} = $options{CONTTYPE});

  }

  return $port;

}

=item B<send_data>

Instruct P4 to display the current file on the specified port.

  $status = $p4->send_data($file, $port);

Returns status.

=cut


sub send_data {
  my $self = shift;
  my ($file, $port) = @_;

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  my $status = $self->obj->obeyw("display", "port=$port data=$file");
  if ($status != ORAC__OK) {
    orac_err("Error displaying image\n");
    orac_err("Trying to execute: display port=$port data=$file\n");
  }
  return $status;
}


=back

=head1 DISPLAY METHODS

=over 4

=cut


=item B<image>

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

  my $port = $self->process_options(%options);

  orac_print("IMAGE:....Port is $port\n",'cyan') if $DEBUG;

  # If port is now undef we have a problem
  unless (defined $port) {
    orac_err("Error processing options. Possible invalid port designation\n");
    return ORAC__ERROR;
  }

  # And set the display_type to IMAGE
  $self->nbs->poke(".port_$port" .".display_type", 'IMAGE');

  # Now ask P4 to display
  my $status = $self->send_data($file, $port);

  return $status;
}

=item B<graph>

Display a graph (spectrum).
Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

=cut

sub graph {

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

  my $port = $self->process_options(%options);

  orac_print("GRAPH:....Port is $port\n",'cyan') if $DEBUG;

  # If port is now undef we have a problem
  unless (defined $port) {
    orac_err("Error processing options. Possible invalid port designation\n");
    return ORAC__ERROR;
  }

  # And set the display_type to GRAPH
  $self->nbs->poke(".port_$port" .".display_type", 'GRAPH');

  # Now ask P4 to display
  my $status = $self->send_data($file, $port);
  return $status;

}

=item B<histogram>

Display a histogram
Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

=cut

sub histogram {

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

  my $port = $self->process_options(%options);

  orac_print("HISTOGRAM:....Port is $port\n",'cyan') if $DEBUG;

  # If port is now undef we have a problem
  unless (defined $port) {
    orac_err("Error processing options. Possible invalid port designation\n");
    return ORAC__ERROR;
  }

  # And set the display_type to HISTOGRAM
  $self->nbs->poke(".port_$port" .".display_type", 'HISTOGRAM');

  # Now ask P4 to display
  my $status = $self->send_data($file, $port);
  return $status;

}

=item B<overgraph>

Display a graph without clearing.
Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

=cut

sub overgraph {

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

  my $port = $self->process_options(%options);

  orac_print("OVERGRAPH:....Port is $port\n",'cyan') if $DEBUG;

  # If port is now undef we have a problem
  unless (defined $port) {
    orac_err("Error processing options. Possible invalid port designation\n");
    return ORAC__ERROR;
  }

  # And set the display_type to OVERGRAPH
  $self->nbs->poke(".port_$port" .".display_type", 'OVERGRAPH');

  # Now ask P4 to display
  my $status = $self->send_data($file, $port);
  return $status;

}

=item B<surface>

Display a surface plot.
Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

=cut

sub surface {

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

  my $port = $self->process_options(%options);

  orac_print("SURFACE:....Port is $port\n",'cyan') if $DEBUG;

  # If port is now undef we have a problem
  unless (defined $port) {
    orac_err("Error processing options. Possible invalid port designation\n");
    return ORAC__ERROR;
  }

  # And set the display_type to SURFACE
  $self->nbs->poke(".port_$port" .".display_type", 'SURFACE');

  # Now ask P4 to display
  my $status = $self->send_data($file, $port);
  return $status;

}

=item B<contour>

Display a contour plot.
Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

=cut

sub contour {

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

  my $port = $self->process_options(%options);

  orac_print("CONTOUR:....Port is $port\n",'cyan') if $DEBUG;

  # If port is now undef we have a problem
  unless (defined $port) {
    orac_err("Error processing options. Possible invalid port designation\n");
    return ORAC__ERROR;
  }

  # And set the display_type to CONTOUR
  $self->nbs->poke(".port_$port" .".display_type", 'CONTOUR');

  # Now ask P4 to display
  my $status = $self->send_data($file, $port);
  return $status;

}



=back

=head1 SEE ALSO

L<ORAC::Display>, L<ORAC::Display::GAIA>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved

=cut

1;
