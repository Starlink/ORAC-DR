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

=item B<new>

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
  $obj->{FlatIndex} = undef;
  $obj->{BiasIndex} = undef;
  $obj->{SkyIndex} = undef;

  $obj->{DarkNoUpdate} = 0;
  $obj->{FlatNoUpdate} = 0;
  $obj->{BiasNoUpdate} = 0;
  $obj->{SkyNoUpdate} = 0;



  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}


# Methods to access the data

=item B<darkname>

Return (or set) the name of the current dark - no checking

  $dark = $Cal->darkname;


=cut

sub darkname {
  my $self = shift;
  if (@_) { $self->{Dark} = shift unless $self->darknoupdate; }
  return $self->{Dark};
}


=item B<biasname>

Return (or set) the name of the current bias - no checking

  $dark = $Cal->biasname;


=cut

sub biasname {
  my $self = shift;
  if (@_) { $self->{Bias} = shift unless $self->biasnoupdate; }
  return $self->{Bias};
}


=item B<skyname>

Return (or set) the name of the current sky frame - no checking

  $dark = $Cal->skyname;


=cut

sub skyname {
  my $self = shift;
  if (@_) { $self->{Sky} = shift unless $self->skynoupdate; }
  return $self->{Sky};
}

=item B<standardname>

Return (or set) the name of the current standard frame - no checking

  $dark = $Cal->standardname;


=cut

sub standardname {
  my $self = shift;
  if (@_) { $self->{Standard} = shift unless $self->standardnoupdate; }
  return $self->{Standard};
}


=item B<dark>

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
    my $dark = $self->darkindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable dark calibration was found in index file"
      unless defined $dark;
    $self->darkname($dark);
  } else {
    croak("Error in calibration checking - giving up");
  };
};


=item B<darknoupdate>

Stops dark object from updating itself with more recent data

Used when using a command-line override to the pipeline

=cut

sub darknoupdate {
  my $self = shift;
  if (@_) { $self->{DarkNoUpdate} = shift; }
  return $self->{DarkNoUpdate};
}

=item B<flatnoupdate>

Stops flat object from updating itself with more recent data

Used when using a command-line override to the pipeline

=cut

sub flatnoupdate {
  my $self = shift;
  if (@_) { $self->{FlatNoUpdate} = shift; }
  return $self->{FlatNoUpdate};
}

=item B<biasnoupdate>

Stops bias object from updating itself with more recent data

Used when using a command-line override to the pipeline

=cut

sub biasnoupdate {
  my $self = shift;
  if (@_) { $self->{BiasNoUpdate} = shift; }
  return $self->{BiasNoUpdate};
}


=item B<skynoupdate>

Stops sky object from updating itself with more recent data

Used when using a command-line override to the pipeline

=cut

sub skynoupdate {
  my $self = shift;
  if (@_) { $self->{SkyNoUpdate} = shift; }
  return $self->{SkyNoUpdate};
}

=item B<standardnoupdate>

Stops standard object from updating itself with more recent data

Used when using a command-line override to the pipeline

=cut

sub standardnoupdate {
  my $self = shift;
  if (@_) { $self->{StandardNoUpdate} = shift; }
  return $self->{StandardNoUpdate};
}

=item B<bias>

Return (or set) the name of the current bias.

  $bias = $Cal->bias;

=cut

sub bias {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->biasname(shift);
  };

  my $ok = $self->biasindex->verify($self->biasname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->biasname};

  croak("Override bias is not suitable! Giving up") if $self->biasnoupdate;

  # not so good
  if (defined $ok) {
    my $bias = $self->biasindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable bias calibration was found in index file"
      unless defined $bias;
    $self->biasname($bias);
  } else {
    croak("Error in calibration checking - giving up");
  };
};




=item B<mask>

Return (or set) the name of the bad pixel mask

  $mask = $Cal->mask;

=cut


sub mask {
  my $self = shift;
  if (@_) { $self->{Mask} = shift; }
  return $self->{Mask};
}

=item B<rotation>

Return (or set) the name of the rotation transformation matrix

  $rotation = $Cal->rotation;

=cut


sub rotation {
  my $self = shift;
  if (@_) { $self->{Rotation} = shift; }
  return $self->{Rotation};
}


=item B<flatname>

Return (or set) the name of the current flat - no checking

  $flat = $Cal->flatname;


=cut

sub flatname {
  my $self = shift;
  if (@_) { $self->{Flat} = shift unless $self->flatnoupdate; }
  return $self->{Flat};
}


=item B<flat>

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

=cut


sub flat {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->flatname(shift);
  };

  my $ok = $self->flatindex->verify($self->flatname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->flatname};

  croak("Override flat is not suitable! Giving up") if $self->flatnoupdate;

  # not so good
  if (defined $ok) {
    my $flat = $self->flatindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable flat was found in index file"
      unless defined $flat;
    $self->flatname($flat);
  } else {
    croak("Error in calibration checking - giving up");
  };
};



=item B<arc>

Return (or set) the name of the current arc.

  $arc = $Cal->arc;

=cut

sub arc {
  my $self = shift;
  if (@_) { $self->{Arc} = shift; }
  return $self->{Arc};
};

=item B<sky>

Return (or set) the name of the current "sky" frame

=cut

sub sky {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->skyname(shift);
  };

  my $ok = $self->skyindex->verify($self->skyname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->skyname};

  croak("Override sky is not suitable! Giving up") if $self->skynoupdate;

  # not so good
  if (defined $ok) {
    my $sky= $self->skyindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable sky frame was found in index file"
      unless defined $sky;
    $self->flatname($sky);
  } else {
    croak("Error in calibration checking - giving up");
  };
};

=item B<standard>

Return (or set) the name of the current standard.

  $standard = $Cal->standard;

=cut


sub standard {

  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->standardname(shift);
  };

  my $ok = $self->standardindex->verify($self->standardname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->standardname};

  croak("Override standard is not suitable! Giving up") if $self->standardnoupdate;

  # not so good
  if (defined $ok) {
    my $standard= $self->standardindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable standard frame was found in index file"
      unless defined $standard;
    $self->flatname($standard);
  } else {
    croak("Error in calibration checking - giving up");
  };

}

=item B<darkindex> 

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

=item B<flatindex>

Return (or set) the index object associated with the flat index file

=cut

sub flatindex {

  my $self = shift;
  if (@_) { $self->{FlatIndex} = shift; }

  unless (defined $self->{FlatIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.flat";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.flat";
    $self->{FlatIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{FlatIndex}; 


};

=item B<biasindex> 

Return (or set) the index object associated with the bias index file

=cut

sub biasindex {

  my $self = shift;
  if (@_) { $self->{BiasIndex} = shift; }

  unless (defined $self->{BiasIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.bias";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.bias";
    $self->{BiasIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{BiasIndex}; 


};

=item B<skyindex>

Return (or set) the index object associated with the sky index file

=cut

sub skyindex {

  my $self = shift;
  if (@_) { $self->{SkyIndex} = shift; }

  unless (defined $self->{SkyIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.sky";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.sky";
    $self->{SkyIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{SkyIndex}; 


};

=item B<standardindex> 

Return (or set) the index object associated with the standard index file

=cut

sub standardindex {

  my $self = shift;
  if (@_) { $self->{StandardIndex} = shift; }

  unless (defined $self->{StandardIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.standard";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.standard";
    $self->{StandardIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{StandardIndex}; 


};

=item B<thing>

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

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu) and 
Frossie Economou (frossie@jach.hawaii.edu)


=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
