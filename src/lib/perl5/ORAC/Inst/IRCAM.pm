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
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Messaging systems
use ORAC::Msg::ADAM::Control;
use ORAC::Msg::ADAM::Task;

# Status handling
use ORAC::Constants qw/:status/;

# Use .sdf extension
$TAIL = ".sdf";


=head1 SUBROUTINES

=over 4

=item B<start_msg_sys>

Starts the messaging system infrastructure so that monoliths
can be contacted. Returns an array of objects associated
with the messaging systems.

IRCAM uses the ADAM messaging system. (ORAC::Msg::ADAM::Control)

Scratch files are written to ORACDR_TMP directory if defined,
else ORAC_DATA_OUT is used. By default ADAM_USER is set
to be a directory in the scratch file directory. This can be
overridden by supplying an optional flag.

  start_msg_sys($preserve);

If C<$preserve> is true, ADAM_USER will be left untouched. This
enables the pipeline to talk to tasks created by other applications
but does mean that the users ADAM_USER may be filled with unwanted
temporary files. It also has the added problem that on shutdown
the ADAM_USER directory is removed by ORAC-DR, this should not happen
if C<$preserve> is true but is not currently guaranteed.

=cut

sub start_msg_sys {

  # Read flag to control private invocation of message system
  my $preserve = 0;
  $preserve = shift if @_;

  # Set ADAM environment variables
  # process-specific adam dir
  
  # Use ORACDR_TMP, then ORAC_DATA_OUT else /tmp as ADAM_USER directory.
  # Unless we are instructed to preserve ADAM_USER
  my $dir = "adam_$$";  

  unless ($preserve) {

    if (exists $ENV{ORACDR_TMP} && defined $ENV{ORACDR_TMP}
	&& -d $ENV{ORACDR_TMP}) {
    
      $ENV{'ADAM_USER'} = $ENV{ORACDR_TMP}."/$dir";      
      
    } elsif (exists $ENV{'ORAC_DATA_OUT'} && defined $ENV{ORAC_DATA_OUT}
	     && -d $ENV{ORAC_DATA_OUT}) {
      
      $ENV{'ADAM_USER'} = $ENV{ORAC_DATA_OUT} . "/$dir";
      
    } else {
      $ENV{'ADAM_USER'} = "/tmp/$dir";
    }

  }

  # Set HDS_SCRATCH -- unless it is defined already
  # Do not need to set to ORAC_DATA_OUT since this is cwd.

  # Want to modify this variable so that we can fix some ndf2fits
  # feature (etc ?) -- I think the problem came up when trying to convert
  # files from one directory to another when the input directory is 
  # read-only...

  unless (exists $ENV{HDS_SCRATCH}) {
    if (exists $ENV{ORACDR_TMP} && defined $ENV{ORACDR_TMP}
	&& -d $ENV{ORACDR_TMP}) {
      $ENV{HDS_SCRATCH} = $ENV{ORACDR_TMP};
    }
  }

  # Create object
  my $adam = new ORAC::Msg::ADAM::Control;

  # Start messaging
  $adam->init;

  return ($adam);
}



=item B<start_algorithm_engines>

Starts the algorithm engines and returns a hash containing
the objects associated with each monolith.
The routine returns when all the last monolith can be contacted
(so requires that messaging has been initialised before this
routine is called).

IRCAM uses PHOTOM (photom_mon), CCDPACK (ccdpack_red, ccdpack_res, 
ccdpack_reg), KAPPA (kappa_mon, ndfpack_mon), POLPACK (polpack_mon),
CURSA (catselect) and PISA (pisa_mon).

=cut


sub start_algorithm_engines {

  %Mon = ();

  $Mon{photom_mon} =  new ORAC::Msg::ADAM::Task( "photom_mon_$$",
         "$ENV{PHOTOM_DIR}/photom_mon" );

  $Mon{ccdpack_red} = new ORAC::Msg::ADAM::Task( "ccdpack_red_$$",
         "$ENV{CCDPACK_DIR}/ccdpack_red" );
  $Mon{ccdpack_reg} = new ORAC::Msg::ADAM::Task( "ccdpack_reg_$$",
         "$ENV{CCDPACK_DIR}/ccdpack_reg" );
  $Mon{ccdpack_res} = new ORAC::Msg::ADAM::Task( "ccdpack_res_$$",
         "$ENV{CCDPACK_DIR}/ccdpack_res" );

  $Mon{kappa_mon} =   new ORAC::Msg::ADAM::Task( "kappa_mon_$$",
         "$ENV{KAPPA_DIR}/kappa_mon" );
  $Mon{ndfpack_mon} = new ORAC::Msg::ADAM::Task( "ndfpack_mon_$$",
         "$ENV{KAPPA_DIR}/ndfpack_mon" );

  $Mon{pisa_mon} =    new ORAC::Msg::ADAM::Task( "pisa_mon_$$",
         "$ENV{PISA_DIR}/pisa_mon" );

  $Mon{polpack_mon} = new ORAC::Msg::ADAM::Task( "polpack_mon_$$",
         "$ENV{POLPACK_DIR}/polpack_mon" );

  $Mon{catselect}   = new ORAC::Msg::ADAM::Task( "catselect_$$",
         "$ENV{CURSA_DIR}/catselect" );

  return %Mon;
}

=item B<wait_for_algorithm_engines>

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

=head1 ENVIRONMENT

The following environment variables are used by this module:

=over 4

=item B<ORACDR_TMP>

Location of temporary files. If not defined C<ORAC_DATA_OUT>
is used instead. ADAM files and HDS scratch files are written
to this directory. It is recommended that this directory
is on a local disk.

=item B<ORAC_DATA_OUT>

Used as a fallback if C<ORACDR_TMP> is not defined.

=back

=head1 SEE ALSO

L<ORAC::Inst::SCUBA>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

