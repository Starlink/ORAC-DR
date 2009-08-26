package ORAC::Calib::Spectroscopy;

=head1 NAME

ORAC::Calib::Imaging - OIR Spectroscopy Calibration

=head1 SYNOPSIS

  use ORAC::Calib::Spectroscopy;

  $Cal = new ORAC::Calib::Spectroscopy;

=head1 DESCRIPTION

Spectroscopy specific calibration methods.

=cut


# Calibration object for the ORAC pipeline

use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;
use ORAC::Index;
use ORAC::Print;
use File::Spec;

use base qw/ ORAC::Calib::OIR /;

$VERSION = '1.0';

# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a ORAC::Calib::Spectroscopy object.
The object identifier is returned.

  $Cal = new ORAC::Calib::Spectroscopy;

=cut

sub new {

  my $self = shift;
  my $obj = $self->SUPER::new( @_ );

  $obj->{Arc} = undef;
  $obj->{Arlines} = undef;
  $obj->{CalibratedArc} = undef;
  $obj->{Iar} = undef;
  $obj->{Offset} = undef;
  $obj->{Profile} = undef;
  $obj->{Row} = undef;
  $obj->{Standard} = undef;

  $obj->{ArcIndex} = undef;
  $obj->{ArlinesIndex} = undef;
  $obj->{CalibratedArcIndex} = undef;
  $obj->{IarIndex} = undef;
  $obj->{OffsetIndex} = undef;
  $obj->{ProfileIndex} = undef;
  $obj->{RowIndex} = undef;
  $obj->{StandardIndex} = undef;

  $obj->{ArcNoUpdate} = 0;
  $obj->{ArlinesNoUpdate} = 0;
  $obj->{CalibratedArcNoUpdate} = 0;
  $obj->{IarNoUpdate} = 0;
  $obj->{OffsetNoUpdate} = 0;
  $obj->{ProfileNoUpdate} = 0;
  $obj->{RowNoUpdate} = 0;
  $obj->{StandardNoUpdate} = 0;

  # Take no arguments at present
  return $obj;

}

=back

=head2 Accessor Methods

=over 4

=cut

# Methods to access the data.
# ---------------------------

=item B<arc>

Return (or set) the name of the current arc.

  $arc = $Cal->arc;

=cut

sub arc {
  my $self = shift;
  if (@_) { 
    # if we are setting, accept the value and return
    return $self->arcname(shift);
  };

  my $ok = $self->arcindex->verify($self->arcname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->arcname};

  croak("Override arc is not suitable! Giving up") if $self->arcnoupdate;

  # not so good
  if (defined $ok) {
    my $arc = $self->arcindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable arc was found in index file"
      unless defined $arc;
    $self->arcname($arc);
  } else {
    croak("Error in arc calibration checking - giving up");
  };
};

=item B<arlines>

Returns the name of a suitable arlines file.

=cut

sub arlines {

  my $self = shift;
  if (@_) {
    return $self->arlinesname(shift);
  };

  my $ok = $self->arlinesindex->verify($self->arlinesname,$self->thing);

  # happy ending
  return $self->arlinesname if $ok;

  if (defined $ok) {
    my $arlines = $self->arlinesindex->chooseby_negativedt('ORACTIME',$self->thing, 0);

    unless (defined $arlines) {
      # Nothing suitable, give up...
      croak "No suitable arlines file was found in index file"
    }

    # Store the good value
    $self->arlinesname($arlines);

  } else {
    # All fall down....
    croak("Error in determining arlines file - giving up");
  }
}

=item B<calibratedarc>

Returns the name of a suitable calibrated arc file. If no suitable calibrated
arc file can be found, this method returns <undef> rather than croaking as
other calibration options do. This is so this calibration can be skipped if
no calibration arc can be found.

=cut

sub calibratedarc {
  my $self = shift;
  if (@_) {
    return $self->calibratedarcname(shift);
  };

  my $ok = $self->calibratedarcindex->verify($self->calibratedarcname,$self->thing);

  # happy ending
  return $self->calibratedarcname if $ok;

  if (defined $ok) {
   my $calibratedarc = $self->calibratedarcindex->chooseby_negativedt('ORACTIME',$self->thing, 0);

    unless (defined $calibratedarc) {
      # Nothing suitable, return undef.
      return;
    }

    # Store the good value
    $self->calibratedarcname($calibratedarc);

  } else {
    # Nothing suitable, return undef.
    return;
  }
}

=item B<iar>

Returns the name of a suitable Iarc file.

=cut


sub iar {
  my $self = shift;
  if (@_) {
    return $self->iarname(shift);
  };

  my $ok = $self->iarindex->verify($self->iarname,$self->thing);

  # happy ending
  return $self->iarname if $ok;

  if (defined $ok) {
    my $iar = $self->iarindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $iar) {
      # Nothing suitable, give up...
      croak "No suitable Iarc file was found in index file"
    }
    # Store the good value
    $self->iarname($iar);

  } else {
    # All fall down....
    croak("Error in determining Iarc file - giving up");
  }
}

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
    $self->standardname($standard);
  } else {
    croak("Error in standard calibration checking - giving up");
  };

}

# *name methods
# -------------
# Used when a file name is required.

=item B<arcname>

Return (or set) the name of the current arc---no checking.

  $arc = $Cal->arcname;


=cut

sub arcname {
  my $self = shift;
  if (@_) { $self->{Arc} = shift unless $self->arcnoupdate; }
  return $self->{Arc};
}

=item B<arlinesname>

Return (or set) the name of the current arlines.lis file - no checking

  $arlines = $Cal->arlinesname;

=cut

sub arlinesname {
  my $self = shift;
  if (@_) { $self->{Arlines} = shift; }
  return $self->{Arlines};
}

=item B<calibratedarcname>

Return (or set) the name of the current calibrated arc file - no checking.

  $calibratedarc = $Cal->calibratedarcname;

=cut

sub calibratedarcname {
  my $self = shift;
  if ( @_ ) { $self->{CalibratedArc} = shift; }
  return $self->{CalibratedArc};
}

=item B<iarname>

Return (or set) the name of the current Iarc file - no checking

  $iar = $Cal->iarname;


=cut

sub iarname {
  my $self = shift;
  if (@_) { $self->{Iar} = shift; }
  return $self->{Iar};
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

=item B<standardname>

Return (or set) the name of the current standard frame---no checking.

  $dark = $Cal->standardname;

=cut

sub standardname {
  my $self = shift;
  if (@_) { $self->{Standard} = shift unless $self->standardnoupdate; }
  return $self->{Standard};
}


# *cache methods
# --------------
# Used when a value or values (rather than a file) is required.


# *noupdate methods
# -----------------

=item B<arcnoupdate>

Stops arc object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub arcnoupdate {
  my $self = shift;
  if (@_) { $self->{ArcNoUpdate} = shift; }
  return $self->{ArcNoUpdate};
}


=item B<profilenoupdate>

Stops object from updating itself with more recent data.
Used when overrding the profile file from the command-line.

=cut

sub profilenoupdate {

  my $self = shift;
  if (@_) { $self->{ProfileNoUpdate} = shift; }
  return $self->{ProfileNoUpdate};

}

=item B<standardnoupdate>

Stops standard object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub standardnoupdate {
  my $self = shift;
  if (@_) { $self->{StandardNoUpdate} = shift; }
  return $self->{StandardNoUpdate};
}

# *index methods
# --------------

=item B<arcindex>

Return (or set) the index object associated with the arc index file

=cut

sub arcindex {

  my $self = shift;
  if (@_) { $self->{ArcIndex} = shift; }

  unless (defined $self->{ArcIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.arc" );
    my $rulesfile = $self->find_file("rules.arc");
    croak "arc rules file could not be located\n" unless defined $rulesfile;
    $self->{ArcIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{ArcIndex}; 


};


=item B<arlinesindex>

Returns the index object associated with the arlines index file. Index is 
static therefore in calibration directory.

=cut

sub arlinesindex {

    my $self = shift;
    if (@_) { $self->{ArlinesIndex} = shift; }
    
    unless (defined $self->{ArlinesIndex}) {
      my $indexfile = $self->find_file("index.arlines");
      my $rulesfile = $self->find_file("rules.arlines");
      $self->{ArlinesIndex} = new ORAC::Index($indexfile,$rulesfile);
    }

    return $self->{ArlinesIndex}; 
}

=item B<calibratedarcindex>

Returns the index object associated with the calibratedarc index file.
Index is static and therefore in calibration directory.

=cut

sub calibratedarcindex {
  my $self = shift;
  if ( @_ ) { $self->{CalibratedArcIndex} = shift; }

  unless ( defined( $self->{CalibratedArcIndex} ) ) {
    my $indexfile = $self->find_file("index.calibratedarc");
    my $rulesfile = $self->find_file("rules.calibratedarc");
    $self->{CalibratedArcIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{CalibratedArcIndex};
}



=item B<iarindex>

Returns the index object associated with the iar file. 

=cut

sub iarindex {
    my $self = shift;
    if (@_) { $self->{IarIndex} = shift; }
    
    unless (defined $self->{IarIndex}) {
        my $indexfile = "index.iar";
        my $rulesfile = $self->find_file("rules.iar");
        $self->{IarIndex} = new ORAC::Index($indexfile,$rulesfile);
    }

    return $self->{IarIndex}; 
}

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

=item B<standardindex> 

Return (or set) the index object associated with the standard index file

=cut

sub standardindex {

  my $self = shift;
  if (@_) { $self->{StandardIndex} = shift; }

  unless (defined $self->{StandardIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.standard" );
    my $rulesfile = $self->find_file("rules.standard");
    croak "standard rules file could not be located\n" unless defined $rulesfile;
    $self->{StandardIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{StandardIndex}; 


};

=back

=head1 SEE ALSO

L<ORAC::Calib::Imaging>, L<ORAC::Calib::OIR> and
L<ORAC::Calib>.

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>, and
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council.
Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
