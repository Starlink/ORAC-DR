package ORAC::Calib;

=head1 NAME

ORAC::Calib - base class for selecting calibration frames in ORACDR

=head1 SYNOPSIS

  use ORAC::Calib;

  $Cal = new ORAC::Calib;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;


=head1 DESCRIPTION

This module provides the basic methods available to all ORAC::Calib
objects. This class should be used for selecting calibration frames.

Unless specified otherwise, a calibration frame is selected by first,
the nearest reduced frame; second, explicit specification via the
-calib command line option (handled by the pipeline); third, by search
of the appropriate index file.

Note this version: Index files not implemented

=cut


# Calibration object for the ORAC pipeline

use strict;
use Carp;
use vars qw/$VERSION/;
use ORAC::Index;
use ORAC::Print;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=over 4

=item new

Create a new instance of a ORAC::Calib object.
The object identifier is returned.

  $Cal = new ORAC::Calib;

=cut

# NEW - create new instance of Calib

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {};  # Anon hash reference
  $obj->{Thing} = {};		# ditto

  $obj->{Bias} = undef;
  $obj->{Dark} = undef;
  $obj->{Flat} = undef;
  $obj->{Mask} = undef;
  $obj->{Rotation} = undef;
  $obj->{Arc} = undef;
  $obj->{Standard} = undef;
  $obj->{Sky} = undef;

  $obj->{DarkIndex} = undef;

  $obj->{DarkNoUpdate} = 0;



  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}


# Methods to access the data

=item darkname

Return (or set) the name of the current dark - no checking

  $dark = $Cal->dark;


=cut

sub darkname {
  my $self = shift;
  if (@_) { $self->{Dark} = shift unless $self->darknoupdate; }
  return $self->{Dark};
}

=item dark

Return (or set) the name of the current dark - 
checks suitability on return.

=cut

sub dark {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->darkname(shift);
  };

  my $ok = $self->darkindex->verify($self->darkname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->darkname};

  croak("Override dark is not suitable! Giving up") if $self->darknoupdate;

  # not so good
  if (defined $ok) {
    $self->darkname($self->darkindex->choosebydt('ORACTIME',$self->thing));
  } else {
    croak("Error in calibration checking - giving up");
  };
};


=item darknoupdate

Stops dark object from updating itself with more recent data

Used when using a command-line override to the pipeline

=cut

sub darknoupdate {
  my $self = shift;
  if (@_) { $self->{DarkNoUpdate} = shift; }
  return $self->{DarkNoUpdate};
}

=item bias

Return (or set) the name of the current bias.

  $bias = $Cal->bias;

=cut


sub bias {
  my $self = shift;
  if (@_) { $self->{Bias} = shift; }
  return $self->{Bias};
}

=item mask

Return (or set) the name of the bad pixel mask

  $mask = $Cal->mask;

=cut


sub mask {
  my $self = shift;
  if (@_) { $self->{Mask} = shift; }
  return $self->{Mask};
}

=item rotation

Return (or set) the name of the rotation transformation matrix

  $rotation = $Cal->rotation;

=cut


sub rotation {
  my $self = shift;
  if (@_) { $self->{Rotation} = shift; }
  return $self->{Rotation};
}


=item flat

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

=cut


sub flat {
  my $self = shift;
  if (@_) { $self->{Flat} = shift; }
  return $self->{Flat};
}


=item arc

Return (or set) the name of the current arc.

  $arc = $Cal->arc;

=cut

sub arc {
  my $self = shift;
  if (@_) { $self->{Arc} = shift; }
  return $self->{Arc};
};

=item sky

Return (or set) the name of the current "sky" frame

=cut

sub sky {
  my $self = shift;
  if (@_) { $self->{Sky} = shift; }
  return $self->{Sky};
};

=item standard

Return (or set) the name of the current standard.

  $standard = $Cal->standard;

=cut


sub standard {
  my $self = shift;
  if (@_) { $self->{Standard} = shift; }
  return $self->{Standard};
}

=item darkindex 

Return (or set) the index object associated with the dark index file

=cut

sub darkindex {

  my $self = shift;
  if (@_) { $self->{DarkIndex} = shift; }

  unless (defined $self->{DarkIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.dark";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.dark";
    $self->{DarkIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{DarkIndex}; 


};

=item thing

Returns or sets the hash associated with the header of the object
(frame or group or whatever) needed to match calibration criteria
against.

Ending sentences with a preposition is a bug.

=cut

sub thing {

my $self = shift;

# check that we have been passed a hash

  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Thing} = $arg;
  };

return $self->{Thing};


};

=back



=head1 SEE ALSO

L<ORAC::Group> and
L<ORAC::Frame> 

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu) and 
Frossie Economou (frossie@jach.hawaii.edu)


=cut
 
1;
