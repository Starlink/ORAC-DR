package ORAC::Calib::CGS4;

=head1 NAME

ORAC::Calib::CGS4;

=head1 SYNOPSIS

  use ORAC::Calib::CGS4;

  $Cal = new ORAC::Calib::CGS4;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $readnoise = $Cal->readnoise;

=head1 DESCRIPTION

This module contains methods for specifying CGS4-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use strict;
use Carp;
use warnings;

use ORAC::Calib;			# use base class
use ORAC::Print;

use File::Spec;       # for catfile

use base qw/ORAC::Calib/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of extraction rows.

  my $Cal = new ORAC::Calib::CGS4;

=cut

sub new {
  my $self = shift;
  my $obj = $self->SUPER::new(@_);

  # Assumes we have a hash object
  $obj->{RowName}     = undef;
  $obj->{RowIndex}    = undef;
  $obj->{Mask}        = undef;
  $obj->{MaskIndex}   = undef;
  $obj->{MaskNoUpdate} = 0;
  $obj->{Profile}     = undef;
  $obj->{ProfileIndex}= undef;
  $obj->{ProfileNoUpdate} = undef;
  $obj->{Engineering} = undef;
  $obj->{EngineeringIndex} = undef;

  return $obj;

}


=back

=head2 Accessors

=over 4

=item B<engineeringindex>

Return (or set) the index object associated with the engineering
parameters index file.

=cut

sub engineeringindex {
  my $self = shift;
  if( @_ ) { $self->{EngineeringIndex} = shift; }
  unless( defined( $self->{EngineeringIndex} ) ) {
    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'},
                                         "index.engineering" );
    my $rulesfile = $self->find_file( "rules.engineering" );
    croak "engineering rules file could not be located\n" unless defined $rulesfile;
    $self->{EngineeringIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{EngineeringIndex};
}

=item B<maskname>

Return (or set) the name of the current bad pixel mask

  $mask = $Cal->maskname;

The C<mask()> method should be used if a test for suitability of the
mask is required.

=cut


sub maskname {
  my $self = shift;
  if (@_) { $self->{Mask} = shift unless $self->masknoupdate; }
  return $self->{Mask}; 
};


=item B<maskindex>

Return or set the index object associated with the bad pixel mask.

  $index = $Cal->maskindex;

An index object is created automatically the first time this method
is run.

=cut

sub maskindex {

  my $self = shift;
  if (@_) { $self->{MaskIndex} = shift; }
  unless (defined $self->{MaskIndex}) {
     my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.bpm" );
     my $rulesfile = $self->find_file("rules.bpm");
     $self->{MaskIndex} = new ORAC::Index($indexfile,$rulesfile);
   };

  return $self->{MaskIndex};

};

=item B<masknoupdate>

Stops object from updating itself with more recent data.
Used when overrding the mask file from the command-line.

=cut

sub masknoupdate {

  my $self = shift;
  if (@_) { $self->{MaskNoUpdate} = shift; }
  return $self->{MaskNoUpdate};

}

=item B<profilename>

Return (or set) the name of the current profile - no checking

  $profile = $Cal->profilename;

The C<profile()> method should be used if a test for suitability of the
profile is required.

=cut


sub profilename {
  my $self = shift;
  if (@_) { $self->{Profile} = shift unless $self->profilenoupdate; }
  return $self->{Profile};
};

=item B<profile>

Return (or set) the name of the current profile

   $profile = $Cal->profile;

=cut

sub profile {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->profilename(shift);
  };

  my $ok = $self->profileindex->verify($self->profilename,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->profilename};

  croak("Override profile is not suitable! Giving up") if $self->profilenoupdate;

  # not so good
  if (defined $ok) {
    my $profile = $self->profileindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable profile was found in index file"
      unless defined $profile;
    $self->profilename($profile);
  } else {
    croak("Error in profile calibration checking - giving up");
  };
};

=item B<profileindex>

Return or set the index object associated with the profile.

  $index = $Cal->profileindex;

An index object is created automatically the first time this method
is run.

=cut

sub profileindex {

  my $self = shift;
  if (@_) { $self->{ProfileIndex} = shift; }
  unless (defined $self->{ProfileIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'}, "index.profile");
    my $rulesfile = $self->find_file("rules.profile");
    $self->{ProfileIndex} = new ORAC::Index($indexfile,$rulesfile);
   };

  return $self->{ProfileIndex};

};

=item B<profilenoupdate>

Stops object from updating itself with more recent data.
Used when overrding the profile file from the command-line.

=cut

sub profilenoupdate {

  my $self = shift;
  if (@_) { $self->{ProfileNoUpdate} = shift; }
  return $self->{ProfileNoUpdate};

}

=item B<rowname>

Returns the name of the key to use in the index file to retrieve
the currently accepted positions of the positive and negative row.
The value should be compared with the current frame header in order
to guarantee its suitability. The name is usually the name of the
observation frame used to calculate the row positions.

Can be used to set or retrieve the name.

  $name = $Cal->rowname;
  $Cal->rowname($name);

=cut

sub rowname {
  my $self = shift;
  if (@_) { $self->{RowName} = shift; }
  return $self->{RowName};
}

=item B<rowindex>

The ORAC::Index object associated with the extraction row.

=cut

sub rowindex {
  my $self = shift;

  if (@_) { $self->{RowIndex} = shift; }

  unless (defined $self->{RowIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'}, "index.row");
    my $rulesfile = $self->find_file("rules.row");
    $self->{RowIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{RowIndex}; 

}

=back

=head2 General Methods

=over 4

=item B<mask>

Return (or set) the name of the current mask. If a mask is to be returned 
every effrort is made to guarantee that the mask is suitable for use.

  $mask = $Cal->mask;
  $Cal->mask($newmask);

If no suitable mask can be found from the index file (or the currently
set mask is not suitable), C<$ORAC_DATA_CAL/fpa46_long> is returned by
default (so long as the file does exist). Note that a test for
suitability can not be performed since there is no corresponding index
entry for this default mask.

=cut


sub mask {

  my $self = shift;

  if (@_) {
    return $self->maskname(shift);
  };

  my $ok = $self->maskindex->verify($self->maskname,$self->thing);

  # happy ending
  return $self->maskname if $ok;

  croak ("Override mask is not suitable! Giving up") if $self->masknoupdate;

  if (defined $ok) {

    my $mask = $self->maskindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $mask) {

      # Nothing suitable, default to fallback position
      # Check that exists and be careful not to set this as the
      # maskname() value since it has no corresponding index enrty
      my $defmask = $self->find_file("fpa46_long.sdf");
      return $defmask if -e $defmask;

      # give up...
      croak "No suitable bad pixel mask was found in index file"
    }

    # Store the good value
    $self->maskname($mask);

  } else {

    # All fall down....
    croak("Error in determining bad pixel mask - giving up");
  }

}


=item B<rows>

Returns the relevant extraction rows to the caller by comparing
the index entries with the current frame. Suitable
values will be found or the method will abort.

Returns two numbers, the maximum number of beams expected
and a an array of hashes describing the beams that were detected.

  my ($nbeams, @beams) = $Cal->rows;

Returns undef and an empty list and prints a warning if the row can
not be determined from the index file.

Can not be used to set the name of the index key. Use the C<rowname>
method for that.

=cut

sub rows {
  my $self = shift;

  # Compare the current value with the index entry
  my $rowname = $self->rowname;
  my $ok = $self->rowindex->verify( $rowname, $self->thing );

  # If this was not okay we need to search the index
  unless ($ok) {

    $rowname = $self->rowindex->choosebydt('ORACTIME', $self->thing);

    if (defined $rowname) {
      # Store it
      $self->rowname( $rowname );
    } else {
      orac_warn "No suitable row could be found in index file\n";
    }

  }

  # Retrieve the NBEAMS and BEAMS from the index
   my ($nbeams, @beams);
   if (defined $rowname) {

     my $entry = $self->rowindex->indexentry($rowname);
     # Sanity check
     croak "BEAMS could not be found in index entry $rowname\n" 
       unless (exists $entry->{BEAMS});
     croak "NBEAMS could not be found in index entry $rowname\n" 
       unless (exists $entry->{NBEAMS});
     $nbeams = $entry->{NBEAMS};
     @beams = @{$entry->{BEAMS}};
   } else {
     # Could not find it
     $nbeams = undef;
     @beams = ();
   }
   return ( $nbeams, @beams );
}


=back

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
