package ORAC::LogFile;

=head1 NAME

ORAC::LogFile - routines for generating log files

=head1 SYNOPSIS

  use ORAC::LogFile;

  $log = new ORAC::LogFile('logfile.dat');
  $log->header(@header);
  $log->addentry(@lines);
  $log->timestamp(1);

=head1 DESCRIPTION

Provide simple interface to generation of logfiles (eg logging
of seeing statistics, photometry results or pointing logs).

=cut

use strict;
use warnings;
use Carp;
use IO::File;

use vars qw/ $VERSION /;
$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are available:

=over 4

=item B<new>

Create a new instance of ORAC::LogFile and associate it with the 
specified log file.

  $log = new ORAC::LogFile($logfile);

If no argument is supplied, the logfile name must be set explcitly
by using the logfile() method.

This constructor does not create the logfile itself.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Use anon hash
  my $log = {};

  # initialise
  $log->{LogFile} = undef;
  $log->{TimeStamp} = 0;  # No timestamping by default

  bless $log, $class;

  # Set the logfile name if one is specified
  $log->{LogFile} = shift if @_;

  # Return the object
  return $log;
}

=item B<logfile>

Return or set the name of the logfile associated with
this instance. Usually set directly by the constructor.

  $logfile = $log->logfile;
  $log->logfile($logfile);

=cut

sub logfile {
  my $self = shift;
  $self->{LogFile} = shift if @_;
  return $self->{LogFile};
}

=item B<timestamp>

Control whether a timestamp is prepended to each entry
written to the logfile. Default is to not print a timestamp.

  $log->timestamp(1);
  $use = $log->timestamp;

The timestamp will be in UT.

=cut

sub timestamp {
  my $self = shift;
  $self->{TimeStamp} = shift if @_;
  return $self->{TimeStamp};
}

=item B<header>

Write header information to the file. Header information is only
written if the logfile does not previously exist (since if the file
exists already a header is not required). If the logfile does not
exist the logfile is created by this method and all arguments written
to it.  A newline character "\n" is automatically appended to each
line.

  $log->header($line1, $line2);
  $log->header(@lines);

=cut

sub header {
  my $self = shift;

  # Return if no arguments
  return unless @_;

  # Retrieve logfile name
  my $logfile = $self->logfile;

  # Complain if no logfile defined
  croak "Logfile undefined - please set logfile name before attempting to write header\n" unless defined $logfile;

  # Check for file existence and return if it is already there
  return if -e $logfile;

  # Open logfile for write
  my $fh = new IO::File("> $logfile");

  # Print the header
  if (defined $fh) {
    print $fh join("\n", @_) . "\n";  
  } else {
    croak "Unable to open $logfile for write: $!\n";
  }

  return;
}

=item B<addentry>

Add a log entry. Multiple lines can be supplied (eg as an array).
Each line is appended to the logfile (appending a newline "\n"
character to each and prepending a timestamp if required).

  $log->addentry($line);
  $log->addentry(@lines);

The logfile is closed each time this method is invoked.

=cut

sub addentry {
  my $self = shift;

  # Return if no arguments
  return unless @_;

  # Retrieve logfile name
  my $logfile = $self->logfile;

  # Complain if no logfile defined
  croak "Logfile undefined - please set logfile name before attempting to write entry\n" unless defined $logfile;

  # check for the existence of the logfile
  # If it is present, open for append, else open for write.

  my $fh;
  if (-e $logfile) {
    $fh = new IO::File(">> $logfile");
  } else {
    $fh = new IO::File("> $logfile");
  }

  # Write the entry
  if (defined $fh) {
    # Read entries 
    my @entries = @_;

    # If necessary prepend a timestamp to each entry
    if ($self->timestamp) {
      my $stamp = gmtime() . " ";
      foreach (@entries) {
	$_ = $stamp . $_;
      }
    }

    print $fh join("\n", @entries) . "\n";
  } else {
    croak "Unable to open $logfile: $!\n";
  }

  return;
}

1;

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt> and
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
