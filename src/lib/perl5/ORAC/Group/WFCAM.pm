package ORAC::Group::WFCAM;

=head1 NAME

ORAC::Group::WFCAM - class for dealing with WFCAMobservation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::WFCAM;

  $Grp = new ORAC::Group::WFCAM("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to WFCAM. It provides a class derived from B<ORAC::Group::MEF>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::WFCAM> objects.

=cut

# A package to describe a WFCAM group object for the ORAC pipeline

use 5.006;
use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;
use ORAC::Group::MEF;

# Set inheritance

use base qw/ ORAC::Group::MEF /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for WFCAM should go here.  I've combined the headers from
# both the orginal UFTI class as well as the UKIRT class.

my %hdr = (
            EXPOSURE_TIME        => "EXP_TIME",
            DEC_SCALE            => "CDELT2",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            GAIN                 => "GAIN",
            RA_SCALE             => "CDELT1",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
            UTDATE               => "DATE",
            UTEND                => "UTEND",
            UTSTART              => "UTSTART",
            AIRMASS_START        => "AMSTART",
            AIRMASS_END          => "AMEND",
            DEC_BASE             => "DECBASE",
            DETECTOR_READ_TYPE   => "MODE",
            EQUINOX              => "EQUINOX",
            FILTER               => "FILTER",
            NUMBER_OF_OFFSETS    => "NOFFSETS",
            NUMBER_OF_EXPOSURES  => "NEXP",
            OBJECT               => "OBJECT",
            OBSERVATION_NUMBER   => "OBSNUM",
            OBSERVATION_TYPE     => "OBSTYPE",
            RA_BASE              => "RABASE",
            ROTATION             => "CROTA2",
            SPEED_GAIN           => "SPD_GAIN",
            STANDARD             => "STANDARD",
            WAVEPLATE_ANGLE      => "WPLANGLE",
            X_LOWER_BOUND        => "RDOUT_X1",
            X_UPPER_BOUND        => "RDOUT_X2",
            Y_LOWER_BOUND        => "RDOUT_Y1",
            Y_UPPER_BOUND        => "RDOUT_Y2"
	  );

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.

ORAC::Group::WFCAM->_generate_orac_lookup_methods( \%hdr );

sub _to_TELESCOPE {
  return "UKIRT";
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::WFCAM> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::WFCAM;
   $Grp = new ORAC::Group::WFCAM("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.fit' and a fixed part
of 'g'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()

  my $group = $class->SUPER::new(@_);

  # Add some extras now including lists of microstep and jitter sequences

  $group->{ugrps} = [];
  $group->{jgrps} = [];
  $group->{sf} = undef;

  # Configure it

  $group->fixedpart('gf');
  $group->filesuffix('.fit');

  # return the new object
  return $group;
}

=back

=head2 Accessors

=over 4

=item B<allugroups>

This method sets and/or returns the list of microstep sequences that have
so far been defined for the current group. Each item in the list should be
a WFCAM Group object.

    @allugroups = $Grp->allugroups;
    $Grp->allugroups(@allugroups);

=cut

sub allugroups {
    my $self = shift;

    if (@_) {
	@{$self->{ugrps}} = @_;
    }

    if (wantarray()) {
	return @{$self->{ugrps}};
    } else {
	return $self->{ugrps};
    }
}

=item B<alljgroups>

This method sets and/or returns the list of jitter sequences that have
so far been defined for the current group. Each item in the list should
be a WFCAM Group object

    @allugroups = $Grp->alljgroups;
    $Grp->alljgroups(@alljgroups);

=cut

sub alljgroups {
    my $self = shift;

    if (@_) {
	@{$self->{jgrps}} = @_;
    }

    if (wantarray()) {
	return @{$self->{jgrps}};
    } else {
	return $self->{jgrps};
    }
}


=item B<findugroup>

This method locates a microstep sequence of a given name and returns the
group reference to it.

    $grp = $Grp->findugroup(groupname);

=cut

sub findugroup {  
    my $self = shift;

    croak 'Usage: $Grp->findugroup(groupname);' unless @_;
    
    my $ugrp = shift;

    my $match = 0;
    my $grp;
    foreach $grp (@{$self->allugroups}) {
	if ($grp->name == $ugrp) {
	    $match = $grp;
	    last;
        }
    }
    croak "Unable to match ugroup $ugrp" unless $match;
    return($match);
}

=item B<findjgroup>

This method locates a jitter sequence of a given name and returns the
group reference to it.

    $grp = $Grp->findjgroup(groupname);

=cut

sub findjgroup {  
    my $self = shift;

    croak 'Usage: $Grp->findjgroup(groupname);' unless @_;
    
    my $jgrp = shift;

    my $match = undef;
    my $grp;
    foreach $grp (@{$self->alljgroups}) {
	if ($grp->name == $jgrp) {
	    $match = $grp;
	    last;
        }
    }
    croak "Unable to match jgroup $jgrp" unless $match;
    return($match);
}

=item B<pushugroup>

This method will add a microstep sequence group to the current list

    $Grp->pushugroup($grp);

There are no return arguments

=cut

sub pushugroup {
    my $self = shift;

    push(@{$self->allugroups},@_) if (@_);
}

=item B<pushjgroup>

This method will add a microstep sequence group to the current list

    $Grp->pushjgroup($grp);

There are no return arguments

=cut

sub pushjgroup {
    my $self = shift;

    push(@{$self->alljgroups},@_) if (@_);
}

=item B<sfgroup>

Set or retrieve the super frame group

    $sfgroup = $Grp->sfgroup;
    $Grp->sfgroup($sfgroup);

=cut

sub sfgroup {
    my $self = shift;

    if (@_) {
	$self->{sf} = shift;
    }

    return $self->{sf};
}

=item B<sfjgrp>

Retrieve all the members from the superframe group that belong to
a given jitter group. Return a group object with this info

    $sfjg = $Grp->sfjgrp($jitter_name);

=cut

sub sfjgrp {
    my $self = shift;

    croak 'Usage: $Grp->sfjmembers(jitter_name);' unless @_;

    my $jnum = shift;
    my @mem = ();
    foreach my $frm ($self->allmembers) {
	push @mem,$frm if ($frm->jgrp == $jnum);
    }
    my $sfjg = $self->new($jnum);
    $sfjg->allmembers(@mem);
    return($sfjg);
}

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

An example is ORACTIME that should be set to the time of the
observation in hours. Instrument specific frame objects
are responsible for setting this value from their header.

Should be run after a header is set. Currently the hdr()
method calls this whenever it is updated.

Calculates ORACUT and ORACTIME

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME
  # For WFCAM the keyword is simply UTSTART
  # Just return it (zero if not available)
  my $time = $self->hdr('UTSTART');
  $time = 0 unless (defined $time);
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # Calc ORACUT:
  my $ut = $self->hdr('DATE');
  $ut = 0 unless defined $ut;
  $ut =~ s/-//g;  #  Remove the intervening minus sign

  $self->hdr('ORACUT', $ut);
  $new{ORACUT} = $ut;

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Group::MEF>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Jim Lewis E<lt>jrl@ast.cam.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
