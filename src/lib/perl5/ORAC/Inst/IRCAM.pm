package ORAC::Inst::IRCAM;

=head1 NAME

ORAC::Inst::IRCAM - ORAC description of IRCAM

=head1 SYNOPSIS

  use ORAC::Inst::IRCAM;

  @messys = start_msg_sys;
  %Mon = start_algorithm_engines;
  $status = &wait_for_algorithm_engines;
 

=head1 DESCRIPTION

This module provides subroutines for determining instrument
specific behaviour of ORAC. This includes deciding which 
monoliths.

=cut

require Exporter;

@ISA = (Exporter);
@EXPORT = qw(start_algorithm_engines wait_for_algorithm_engines
	    start_msg_sys);

use Carp;
use strict;
use vars qw/$VERSION $TAIL %Mon/;
$VERSION = undef; # -w protection
$VERSION = '0.10';

# Messaging systems
use ORAC::Msg::ADAM::Control;
use ORAC::Msg::ADAM::Task;

# Status handling
use ORAC::Constants qw/:status/;

# Use .sdf extension
$TAIL = ".sdf";


=head1 SUBROUTINES

=over 4

=item start_msg_sys

Starts the messaging system infrastructure so that monoliths
can be contacted. Returns an array of objects associated
with the messaging systems.

IRCAM uses the ADAM messaging system. (ORAC::Msg::ADAM::Control)

=cut

sub start_msg_sys {

  # Set ADAM environment variables
  $ENV{'ADAM_USER'} = "/tmp/adam$$";      # process-specific adam dir

  # Set HDS_SCRATCH -- unless it is defined already
  # Want to modify this variable so that we can fix some ndf2fits
  # feature (etc ?) -- I think the problem came up when trying to convert
  # files from one directory to another when the input directory is 
  # read-only...
  $ENV{HDS_SCRATCH} = $ENV{ORAC_DATA_OUT} unless exists $ENV{HDS_SCRATCH};

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

IRCAM uses PHOTOM (photom_mon), CCDPACK (ccdpack_red, ccdpack_res, 
ccdpack_reg), FIGARO (figaro1), KAPPA (kappa_mon), and PISA (pisa_mon).

=cut


sub start_algorithm_engines {

  %Mon = ();

  ($ENV{PSF_DIR} = '/star/local/bin') unless (exists $ENV{PSF_DIR});

  $Mon{photom_mon} = new ORAC::Msg::ADAM::Task("photom_mon_$$",$ENV{PHOTOM_DIR}."/photom_mon");
  $Mon{figaro1} = new ORAC::Msg::ADAM::Task("figaro1_$$",$ENV{FIG_DIR}."/figaro1");
  $Mon{ndfpack_mon} = new ORAC::Msg::ADAM::Task("ndfpack_mon_$$",$ENV{KAPPA_DIR}."/ndfpack_mon");
  $Mon{ccdpack_red} = new ORAC::Msg::ADAM::Task("ccdpack_red_$$",$ENV{CCDPACK_DIR}."/ccdpack_red");
  $Mon{ccdpack_res} = new ORAC::Msg::ADAM::Task("ccdpack_res_$$",$ENV{CCDPACK_DIR}."/ccdpack_res");
  $Mon{ccdpack_reg} = new ORAC::Msg::ADAM::Task("ccdpack_reg_$$",$ENV{CCDPACK_DIR}."/ccdpack_reg");
  $Mon{kappa_mon} = new ORAC::Msg::ADAM::Task("kappa_mon_$$",$ENV{KAPPA_DIR}."/kappa_mon");
  $Mon{pisa_mon} = new ORAC::Msg::ADAM::Task("pisa_mon_$$",$ENV{PISA_DIR}."/pisa_mon");
  $Mon{psf_mon} = new ORAC::Msg::ADAM::Task("psf_mon_$$",$ENV{PSF_DIR}."/psf");

  return %Mon;
}

=item wait_for_algorithm_engines

Check to see that at least one of the algorithm engines has 
started. Wait until contact can be made or timeout is reached.
Return ORAC__OK if everything works; ORAC__ERROR if
a timeout.

The messaging system must be running and the algorithm engine objects
must have been created via start_algorithm_engines().

=cut

sub wait_for_algorithm_engines {

  if ( $Mon{kappa_mon}->contactw ) {
    return ORAC__OK;
  } else {
    return ORAC__ERROR;
  }
}


=back

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)


=cut

