package ORAC::Calib::ACSIS;

=head1 NAME

ORAC::Calib::ACSIS;

=head1 SYNOPSIS

  use ORAC::Calib::ACSIS;

  $Cal = new ORAC::Calib::ACSIS;

=head1 DESCRIPTION

This module contains methods for specifying ACSIS-specific calibration
objects. It provides a class derived from ORAC::Calib. All the methods
available to ORAC::Calib objects are also available to
ORAC::Calib::ACSIS objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Copy;
use File::Spec;

use base qw/ ORAC::Calib::JCMT /;

use vars qw/ $VERSION /;
$VERSION = '1.0';


# Define default parameters for sideband correction.
my %SIDEBANDCORR = (RXA3M => [
                        {
                         START => 20160101,
                         A => 0.782164242,
                         B => 0.331811472,
                         C => 54.63449674,
                         D => -313.5952557,
                         E => -4833.576982,
                        }
                    ],
    );




__PACKAGE__->CreateBasicAccessors( bad_receptors => { staticindex => 1 },
                                   flat => { staticindex => 1 },
                                   standard => { staticindex => 1 },
);


=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of pointing, reference
spectrum, beam efficiency, and other ACSIS-specific calibration
information.

=cut

sub new {
  my $self = shift;
  my $obj = $self->SUPER::new( @_ );

# This assumes we have a hash object.
  $obj->{BadReceptors} = undef;
  $obj->{BadReceptorsIndex} = undef;
  $obj->{BadReceptorsNoUpdate} = 0;
  $obj->{Flat} = undef;
  $obj->{FlatIndex} = undef;
  $obj->{Standard} = undef;
  $obj->{StandardIndex} = undef;
  $obj->{StandardNoUpdate} = 0;
  $obj->{SidebandCorrIndex} = undef;

  return $obj;
}

=back

=head2 Accessors

=over 4

=item B<bad_receptors>

Set or retrieve the name of the system to be used for bad receptor
determination. Allowed values are:

=over 4

=item * master

Use the master index.bad_receptors index file in $ORAC_DATA_CAL.

=item * index

Use the index.bad_receptors_qa index file in $ORAC_DATA_OUT as
generated by the pipeline.

=item * indexormaster

Use both the master index.bad_receptors and pipeline-generated
index.bad_receptors_qa file. Results are 'or'ed together, so any
receptors flagged as bad in either index file will be flagged as bad.

=item * file

Use the contents of the file F<bad_receptors.lis>, which contains a
space-separated list of receptor names in the first line. This file
must be found in $ORAC_DATA_OUT. If the file cannot be found, no
receptors will be flagged.

=item * 'list'

A colon-separated list of receptor names can be supplied.  This list
can be in combination with one of the other options.

=back

The default is to use the 'indexormaster' method. The returned value
will always be in upper-case.

=cut

sub bad_receptors {
  my $self = shift;
  # Use the automatically created method
  my $br = $self->bad_receptorscache(map { uc($_) } @_);
  return ( defined $br ? $br : "INDEXORMASTER" );
}

=item B<bad_receptorsindex>

Return (or set) the index object associated with the master bad
receptors index file. This index file is used if bad_receptors() is
set to 'MASTER' or 'INDEXORMASTER'.

=item B<bad_receptors_qa_index>

Return (or set) the index object associated with the
pipeline-generated bad receptors index file. This index file is used
if bad_receptors() is set to 'INDEX' or 'INDEXORMASTER'.

=cut

sub bad_receptors_qa_index {
  my $self = shift;
  return $self->GenericIndex( "bad_receptors_qa", "dynamic", @_ );
}

=item B<bad_receptors_list>

Return a list of receptor names that should be masked as bad for the
current observation. The source of this list depends on the setting of
the bad_receptors() accessor.

=cut

sub bad_receptors_list {
  my $self = shift;

  # Retrieve the bad_receptors query system.
  my $sys = $self->bad_receptors;

  # Array to hold the bad receptors.
  my @bad_receptors = ();

  # Protect against the case where the user provides a list and one of the
  # other options separated by a comma rather than a colon.
  if ( $sys =~ /ARRAY/ ) {
     orac_throw( "Syntax error in bad_receptors calibration specification.  " .
                 "Elements should be separated by colons.\n" );
  }

  my $usefile = index( $sys, 'FILE' ) != -1 ;
  my $useindex = index( $sys, 'INDEX' ) != -1;
  my $usemaster = index( $sys, 'MASTER' ) != -1;

  # Validate the receptor name for old instruments and U'u, ignoring
  # other bad_receptor modes.
  my @valid_receptors = $self->receptor_names;
  push @valid_receptors, ( "INDEX", "FILE", "MASTER", "MASTERORINDEX" );

  my $uselist = 1;
  foreach my $receptor ( split /:/, $sys ) {
    if ( ! grep( /^$receptor$/, @valid_receptors ) ) {
      $uselist = 0;
      my $instrument = $self->thing->{'ORAC_INSTRUMENT'};
      orac_warn "List mode for bad_receptors is disabled because " .
                "$receptor is not permitted for $instrument.\n";
    }
  }

  # Go through each system.
  if ( $useindex || $usemaster ) {

    # We need to set up some temporary headers for LOFREQ_MIN and
    # LOFREQ_MAX. The "thing" method contains the merged uhdr and hdr,
    # so just stick them in there. The uhdr is in "thingtwo".
    my $lofreq = $self->thing->{'LOFREQS'};
    my $thing2 = $self->thingtwo;
    $thing2->{'LOFREQ_MIN'} = $lofreq;
    $thing2->{'LOFREQ_MAX'} = $lofreq;
    $self->thingtwo( $thing2 );

    my @master_bad = ();
    my @index_bad = ();

    if ( $usemaster ) {

      my $brposition = $self->bad_receptorsindex->chooseby_negativedt( 'ORACTIME', $self->thing, 0 );

      if( defined( $brposition ) ) {

        # Retrieve the specific entry, and thus the receptors.
        my $brref = $self->bad_receptorsindex->indexentry( $brposition );
        if( exists( $brref->{'DETECTORS'} ) ) {
          @master_bad = split /,/, $brref->{'DETECTORS'};
        } else {
          croak "Unable to obtain DETECTORS from master index file entry $brposition\n";
        }
      }
    }

    if ( $useindex ) {

      # This one also has a modified SURVEY_BR, so set that based on
      # the SURVEY header.
      my $survey = $self->thing->{'SURVEY'};
      my $thing2 = $self->thingtwo;
      if( ! defined( $thing2->{'SURVEY_BR'} ) ) {
        if( defined( $survey ) ) {
          $thing2->{'SURVEY_BR'} = $survey;
        } else {
          $thing2->{'SURVEY_BR'} = 'Telescope';
        }
        $self->thingtwo( $thing2 );
      }

      my $brposition = $self->bad_receptors_qa_index->choosebydt( 'ORACTIME', $self->thing, 0 );

      if( defined( $brposition ) ) {
        # Retrieve the specific entry, and thus the receptors.
        my $brref = $self->bad_receptors_qa_index->indexentry( $brposition );
        if( exists( $brref->{'DETECTORS'} ) ) {
          @index_bad = split /,/, $brref->{'DETECTORS'};
        } else {
          croak "Unable to obtain DETECTORS from QA index file entry $brposition\n";
        }
      }

    }

    # Remove the temporary LOFREQ_MIN and LOFREQ_MAX headers.
    $thing2 = $self->thingtwo;
    delete $thing2->{'LOFREQ_MIN'};
    delete $thing2->{'LOFREQ_MAX'};
    $self->thingtwo( $thing2 );

    # Merge the master and QA bad receptors.
    my %seen = map { $_, 1 } @master_bad, @index_bad;
    @bad_receptors = keys %seen;

  } elsif ( $usefile ) {

    # Look for bad receptors in the bad_receptors.lis file.
    my $file = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "bad_receptors.lis" );
    if( -e $file ) {
      my $fh = new IO::File( "< $file" );
      if( defined( $fh ) ) {
        my $list = <$fh>;
        close $fh;
        @bad_receptors = split( /\s+/, $list );
      }
    }
  }

  if ( $uselist ) {

    # Remove other options and delimiters.
    $sys =~ s/INDEXORMASTER//;
    $sys =~ s/INDEX//;
    $sys =~ s/MASTER//;
    $sys =~ s/FILE//;
    $sys =~ s/,//;
    $sys =~ s/::/:/;

    # Look for bad receptors in $sys itself.
    my @list_bad = split /:/, $sys;

    # Merge the list receptor with those from other sources.
    my %seen = map { $_, 1 } @bad_receptors, @list_bad;
    @bad_receptors = keys %seen;

  }

  return @bad_receptors;
}

=item B<flat>

Retrieve flat-field ratios for the observation's UT date.

=cut

sub flat {
  my $self = shift;

  # Find the nearest flat calibration in the index file.
  my $flat_position = $self->flatindex->choosebydt( 'ORACTIME', $self->thing, 0 );

  # $uhdrref is a reference to the Frame uhdr hash.
  my $uhdrref = $self->thingtwo;
  my $instname = $uhdrref->{'ORAC_INSTRUMENT'};

  # Flat fielding only applies to HARP data.
  if ( ! ( defined( $flat_position ) && $instname =~ /HARP/ ) ) {
    return undef;
  }

  my ( %ratios, @receptors, $receptor_name );

  # $uhdrref is a reference to the Frame hdr hash.
  my $hdrref = $self->thing;

  # Form the array of receptor names needed.  This implies that the
  # rules.flat file needs to be created on the fly if RECPTORS does
  # include the full 16, as will be the normal case except in the early
  # observations (after which non-functioning receptors were omitted
  # from the time-series cubes to reduce storage requirements), and
  # hence be the case for a user's index.flat.  The master index will
  # contain all 16.  Should the user omit a receptor from
  # $ORAC_DATA_OUT/index.flat, the pipeline will exit with an error
  # citing a mismatch of the number of columns and keys.
  if ( defined( $hdrref->{'RECPTORS'} ) ) {
    @receptors = split / /, $hdrref->{'RECPTORS'};
  } else {
    foreach my $i ( 0..15 ) {
      $receptor_name = "H" . printf("%02d", $i );
      push @receptors, $receptor_name;
    }
  }

  my $flatref = $self->flatindex->indexentry( $flat_position );

  # Retrieve the specific entry, and then the receptors relative
  # performances.  The sensible default of 1.0 should still give
  # presentable results.
  foreach my $r ( @receptors ) {
    if ( exists( $flatref->{ $r } ) ) {
      $ratios{ $r } = $flatref->{ $r };
    } else {
      $ratios{ $r } = 1.0;
    }
  }
  return %ratios;
}

=item B<standard>

Retrieve the relevant standard.

=cut

sub standard {
  my $self = shift;

  return $self->standardcache(shift) if @_;

  if( $self->standardnoupdate ) {
    my $cache = $self->standardcache;
    return $cache if defined $cache;
  }

  # We need to convert the transition in the header into something we
  # can use. This means stripping out spaces. Also strip out dashes
  # from the molecule.
  my $transition = $self->thing->{'TRANSITI'};
  my $molecule = $self->thing->{'MOLECULE'};
  my $thing2 = $self->thingtwo;
  $transition =~ s/\s+//g;
  $thing2->{'TRANSITION'} = $transition;
  $molecule =~ s/\s+//g;
  $molecule =~ s/-//g;
  $thing2->{'MOLECULE'} = $molecule;

  $self->thingtwo( $thing2 );

  my $standardfile = $self->standardindex->choosebydt( 'ORACTIME', $self->thing, 0 );

  if( ! defined( $standardfile ) ) {
    return undef;
  }

  my $standardref = $self->standardindex->indexentry( $standardfile );
  if( exists( $standardref->{'INTEGINT'} ) &&
      exists( $standardref->{'PEAK'} ) &&
      exists( $standardref->{'L_BOUND'} ) &&
      exists( $standardref->{'H_BOUND'} ) ) {
    return $standardref;
  } else {
    croak "Unable to obtain INTEGINT, PEAK, L_BOUND, and H_BOUND from index file entry $standardfile\n";
  }
}

=item B<receptor_names>

This returns the permitted receptors names for the current instrument.
It first looks for the header, and failing that supplies the default
set.

  @receptors = $Cal->receptor_names();
  @receptors = $Cal->receptor_names($instrument);

=cut

sub receptor_names {
  my $self = shift;
  my $instrument = shift;
  if ( !$instrument ) {
    $instrument = $self->thing->{'ORAC_INSTRUMENT'};
  }
  $instrument = uc( $instrument );

  # Form an array of valid receptor names for the respective instruments.
  # The available ones should be recorded in the FITS header, but
  # include default sets of receptor names by instrument, just in case
  # the header is absent or null.
  my @receptors;
  if ( defined( $self->thing->{'RECPTORS'} ) ) {
    @receptors = split / /, $self->thing->{'RECPTORS'};

  } else {
    if ( $instrument eq "HARP" ) {
      foreach my $i ( 0..15 ) {
        my $receptor_name = "H" . printf("%02d", $i );
        push @receptors, $receptor_name;
      }

    } elsif ( $instrument =~ /^RXA/ ) {
      @receptors = ( "A" );

    } elsif ( $instrument =~ /^RXB/ ) {
      @receptors = ( "A", "B" );

    } elsif ( $instrument =~ /^RXW/ ) {
      @receptors = ( "CA", "CB", "DA", "DB" );

    } elsif ( $instrument eq /UU/ ) {
      @receptors = ( "NU0L", "NU1L", "NU0U", "NU1U" );

    } elsif ( $instrument eq "AWEOWEO" ) {
      @receptors = ( "NW0L", "NW0U", "NW1L", "NW1U" );

    } elsif ( $instrument eq "ALAIHI" ) {
      @receptors = ( "NA0", "NA1" );
    }
  }

  return @receptors;
}

=item B<sidebandcorr_factor>

Calculate the sideband correction factor. Requires an instrument, a
time and an lofrequency, which it gets from the headers by default

  $factor = $Cal->sidebandcorr_factor();

Optionally you can specify the instrument, ut and lo frequency (GHz)
in the call.

  $factor = $Cal->sidebandcorr_factor($instrument, $ut, $lo_freq);



=cut

sub sidebandcorr_factor {
    my $self = shift;
    my $instrument = shift;
    if (!$instrument) {
        $instrument = $self->thing->{'ORAC_INSTRUMENT'};
        $instrument = uc($instrument);
    } else {
        $instrument = uc($instrument);
    }
    my $ut = shift;

    if (!$ut) {
        $ut = $self->thing->{'ORACTIME'};
    }

    # Get the time dependent list of factors for this instrument.
    my $CORRFACTORS = $SIDEBANDCORR{$instrument};

    unless ( $CORRFACTORS) {
        orac_warn "No side band correction factors are defined for the specified instrument ($instrument).\n";
        return;
    }

    # Do this afterwards, as we want to ensure a useful warning is produced.
    my $lo_freq = shift;
    if (!$lo_freq) {
        # We are assuming lo_freq is given in GHz.
        if (! $self->thing->{'LOFREQS'} ) {
            orac_err "Cannot calculate sideband correction factor as LOFREQS is not available.\n";
            return;
        } else {
            $lo_freq = 0.5 * ($self->thing->{'LOFREQS'} + $self->thing->{'LOFREQE'});
            orac_debug "LO frequency is $lo_freq GHz.\n";
        }
    }

    my $match;
    my $gl_over_gu;

    if ($CORRFACTORS) {
        # Now find one that overlaps in time.
        my $infstart = 19900101;
        my $infend =   30000101;
        for my $f (@$CORRFACTORS) {
            my $start = (exists $f->{START} ? $f->{START} : $infstart);
            my $end = (exists $f->{END} ? $f->{END} : $infend);

            if ($start <= $ut && $end >=$ut) {
                $match = $f;
                last;
            }
        }

        if ($match) {
            my $A = $match->{'A'};
            my $B = $match->{'B'};
            my $C = $match->{'C'};
            my $D = $match->{'D'};
            my $E = $match->{'E'};
            orac_debug "Correction polynomial fit factors from CAL SYSTEM are $A, $B, $C, $D, $E .\n";
            my $x = ($lo_freq - 245)/245.0;

            $gl_over_gu = $A + $B*$x + $C *$x**2 + $D*$x**3 + $E*$x**4;
        } else {
            orac_warn "No sideband correction factors defined for instrument=$instrument on UT=$ut.\n";
        }
    }
    return $gl_over_gu;

}

=back

=head2 Support Methods

Each of the methods above has a support implementation to obtain
the index file, current name and whether the value can be updated
or not. For method "cal" there will be corresponding methods
"calindex", "calname" and "calnoupdate". "calcache" is an
allowed synonym for "calname".

  $current = $Cal->calcache();
  $index = $Cal->calindex();
  $noup = $Cal->calnoupdate();

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
Malcolm J. Currie <mjc@jach.hawaii.edu>

=head1 COPYRIGHT

Copyright (C) 2007-2009, 2014, 2016, 2020 Science and Technology Facilities Council.
All Rights Reserved.

=cut

1;
