package ORAC::Inst::ADAM;

=head1 NAME

ORAC::Inst::ADAM - ADAM specific instrument initialisation routines

=head1 SYNOPSIS

  use ORAC::Inst::ADAM;

  @msg = $inst->start_mgs_sys;


=head1 DESCRIPTION

Implementation of C<ORAC::Inst::InitMsg> for ADAM based instruments.
This is a sub-class of C<ORAC::Inst::InitMsg> that is itself
sub-classed by each ADAM based instrument.

=cut

use strict;
use Carp;

use ORAC::Msg::ADAM::Control;
use ORAC::Msg::ADAM::Task;

use ORAC::Constants qw/:status/;

use base qw/ ORAC::Inst::InitMsg /;

=head1 METHODS

=over 4

=item B<start_msg_sys>

Starts the messaging system infrastructure so that monoliths
can be contacted. Returns an array of objects associated
with the messaging systems.

Scratch files are written to ORACDR_TMP directory if defined,
else ORAC_DATA_OUT is used. By default ADAM_USER is set
to be a directory in the scratch file directory. This can be
overridden by supplying an optional flag.

  @msgobj = $inst->start_msg_sys($preserve);

If C<$preserve> is true, ADAM_USER will be left untouched. This
enables the pipeline to talk to tasks created by other applications
but does mean that the users ADAM_USER may be filled with unwanted
temporary files. It also has the added problem that on shutdown
the ADAM_USER directory is removed by ORAC-DR, this should not happen
if C<$preserve> is true but is not currently guaranteed.

=cut

sub start_msg_sys {
  my $self = shift;

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

  # Store the object
  @{ $self->_msgsys } = ($adam);

  # Return the object
  return ($adam);

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

L<ORAC::Inst::MsgInit>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
