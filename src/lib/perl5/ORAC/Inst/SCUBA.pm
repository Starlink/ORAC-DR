package ORAC::Inst::SCUBA;

=head1 NAME

ORAC::Inst::SCUBA - ORAC description of SCUBA

=head1 SYNOPSIS

  use ORAC::Inst::SCUBA;

  &start_msg_sys;
  &start_algorithm_engines;

=head1 DESCRIPTION

This module provides subroutines for determining instrument
specific behaviour of ORAC. This includes deciding which 
monoliths.

=cut

require Exporter;

@ISA = (Exporter);
@EXPORT = qw(start_algorithm_engines
	    start_msg_sys);

use Carp;
use strict;
use vars qw/$VERSION $TAIL/;
$VERSION = undef; # -w protection
$VERSION = '0.10';

use ORAC::Msg::ADAM::Control;
use ORAC::Msg::ADAM::Task;


# Use .sdf extension
$TAIL = ".sdf";


=head1 SUBROUTINES

=over 4

=item start_msg_sys

Starts the messaging system infrastructure so that monoliths
can be contacted. Returns an array of objects associated
with the messaging systems.

SCUBA uses the ADAM messaging system. (ORAC::Msg::ADAM::Control)

=cut

sub start_msg_sys {

  # Set ADAM environment variables
  $ENV{'HDS_SCRATCH'} = "/tmp";           # fix ndf2fits (etc ?)  "feature"
  $ENV{'ADAM_USER'} = "/tmp/adam$$";      # process-specific adam dir

  # Create object
  my $adam = new ORAC::Msg::ADAM::Control;

  # Start messaging
  $adam->init;

  return ($adam);
}




=item start_algorithm_engines

Starts the algorithm engines and returns a hash containing
the objects associated with each monolith.
The routine returns when all the last monolith can be contacted
(so requires that messaging has been initialised before this
routine is called).

SCUBA uses SURF (surf_mon)
and  KAPPA (kapview_mon, kappa_mon, ndfpack_mon)

=cut

sub start_algorithm_engines {

  my %Mon = ();

  $Mon{surf_mon} = new ORAC::Msg::ADAM::Task("surf_mon_$$", "/jcmt_sw/scuba/redsdir/surf_mon");
 
  $Mon{kapview_mon} = new ORAC::Msg::ADAM::Task("kapview_mon_$$",$ENV{KAPPA_DIR}."/kapview_mon");
  $Mon{ndfpack_mon} = new ORAC::Msg::ADAM::Task("ndfpack_mon_$$",$ENV{KAPPA_DIR}."/ndfpack_mon");

  $Mon{kappa_mon} = new ORAC::Msg::ADAM::Task("kappa_mon_$$",$ENV{KAPPA_DIR}."/kappa_mon");
  $Mon{kappa_mon}->contactw;	# wait for last monolith

  return %Mon;
}



=back

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)


=cut

