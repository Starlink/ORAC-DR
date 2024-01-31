package ORAC::Loop;

=head1 NAME

ORAC::Loop - data loops for ORACDR

=head1 SYNOPSIS

  use ORAC::Loop;

  $frm = orac_loop_list($class, $utdate, \@list, $skip);

  $frm = orac_loop_inf($class, $utdate, \@list);

  $frm = orac_loop_wait($class, $utdate, \@list, $skip);

  $frm = orac_loop_flag($class, $utdate, \@list, $skip);

  $frm = orac_loop_task( $class, \@array, $skip );

  $frm = orac_loop_file($class, \@list );

=head1 DESCRIPTION

This module provides a set of loop handling routines for ORACDR.
Each subroutine accepts the same arguments and returns the current
observation number (or undef if there was an error or if the loop
should be terminated).

A new  Frame object is returned of class $class that has been configured
for the new file (ie a C<$Frm-E<gt>configure> method has been run)

It is intended that this routine is called inside an infinite while
loop with the same @list array. This array is modified by the loop
routines so that they can keep track of the 'next' frame number.

If a filename can not be found (eg it doesnt exist or the list has
been processed) undef is returned.

The skip flag is used to indicate whether the loop should skip
forward if the current observation number can not be found
but a higher numbered observation is present. Currently no loops
will go back to missing observations if they appear after a higher
number (eg observation 10 appears before observation 9!)

=cut

use strict;
use warnings;
use Carp;

use IO::Uncompress::Gunzip qw/ gunzip $GunzipError /;
use Time::HiRes;
use File::Basename;
use File::Find;
use Cwd;

use ORAC::Error qw/ :try /;
use ORAC::General;
use ORAC::Print;
use ORAC::Convert;
use ORAC::Msg::EngineLaunch;    # For -loop 'task'

use Astro::FITS::HdrTrans qw/ translate_from_FITS /;

require Exporter;

use vars qw/$VERSION @EXPORT @ISA $CONVERT $ENGINE_LAUNCH/;

$VERSION = '1.0';

@ISA = qw/Exporter/;
@EXPORT = qw/ orac_loop_list  orac_loop_wait orac_loop_inf orac_loop_task
              orac_loop_flag orac_loop_file orac_check_data_dir /;

# Should multiple flag files be read "in sync"?
# (Controls the behavior of _read_flagfiles.)
our $read_flag_sync = 0;

=head1 LOOP SUBROUTINES

The following loop facilities are available:

=over 4


=item B<orac_loop_list>

Takes a list of numbers and returns back a frame object
for each number (one frame object per call)

  $Frm = orac_loop_list($class, $UT, \@array, $noskip);

undef is returned on error or when all members of the
list have been returned. If the 'skip' flag is true
missing files in the list will be ignored and the next
element of the list selected. If 'skip' is false
the loop will abort if the file is not present

=cut

  sub orac_loop_list {
    #print "in orac_loop_list\n";
    croak 'Wrong number of args: orac_loop_list(class, ut, arr_ref, skip)'
      unless scalar(@_) == 4;

    my ($class, $utdate, $obsref, $skip) = @_;

    # Initialise variables
    my $obsno;
    my $TestFrm;
    $TestFrm = $class->new() if $skip; # Dummy Frame for file check

    # Shift files off the array until we get one that exists
    # or until we get to the end of the array [ie an undefined value]
    # If we dont worry about missing observations we immediately
    # jump out of the loop (ie just read the array once).
    # If we do care about the existence of the file we have to check
    # for the input file (-e) and loop round again if it isn't there.

    while (defined ($obsno = shift(@$obsref))) {

      # If we dont care whether the file is there or not (ie default mode)
      # we jump out of the loop immediately and rely on the link_and_read
      # routine to abort the main loop for us (by returning undef)
      if( $skip ) {

        # Ok - we are interested in finding out whether the file is
        # there or not. There is a slight overhead here in that we
        # have to do the -e test twice for any successful file. Once
        # here and once again in link_and_read -- presumably I could
        # have a variant on link_and_read that gets passed the file
        # name directly on the understanding that the file is there
        # but for now I will just do the -e in both places. Note that
        # this relies on the file being present in ORAC_DATA_IN. It
        # will not look in ORAC_DATA_OUT first (eg after a FITS
        # conversion) At some point we need to merge the link_and_read
        # with this so that this routine has the same robustness as
        # link_and_read.

        my $pattern = $TestFrm->pattern_from_bits($utdate, $obsno);

        my @names = _find_from_pattern( $pattern );

        if ( ! scalar( @names ) ) {
          if ( ref( $pattern ) eq 'Regexp' ) {
            orac_warn("No input files for observation $obsno found -- skipping\n");
          } else {
            orac_warn("Input file $pattern not found -- skipping\n");
          }
          next;
        }
      }

      # If obsno is undef return undef
      return unless defined $obsno;

      my @Frms;
      my $Error;
      try {
        @Frms = link_and_read( $class, $utdate, $obsno, 0 );
      } otherwise {
        $Error = shift;
      };
      if( defined( $Error ) ) {
        ORAC::Error->flush;
        if( $skip ) {
          orac_warn "${Error}-skip mode, skipping to next file\n";
        } else {
          orac_throw "$Error";
          return undef;
        }
      } else {
        return @Frms;
      }

    }

    return undef;

  }

=item B<orac_loop_inf>

Checks for the frame stored in the first element of the supplied array
and returns the Frame object if the file exists. The number is incremented
such that the next observation is returned next time the routine is
called.

  $Frm = orac_loop_inf($class, $ut, \@array);

undef is returned on error or when there are no more data files
available.

This loop does not have a facility for skipping files when observations
are not present. This behaviour is obtained by combining
orac_check_data_dir with the list looping option so that the last
observation number can be determined before running the loop. The skip
flag is ignored in this loop.

=cut

sub orac_loop_inf {
  #print "in orac_loop_inf\n";
  croak 'Wrong number of args: orac_loop_inf(class, ut, arr_ref)'
    unless (scalar(@_) == 3 || scalar(@_) == 4);

  my ($class, $utdate, $obsref) = @_;

  # If obsno is undef return undef
  return unless defined $$obsref[0];

  # Get the obsno
  my $obsno = $$obsref[0];

  my @Frms = link_and_read($class, $utdate, $obsno, 0);

  # Now need to increment the obsnum for next time around
  $$obsref[0]++;

  # Return frame
  return @Frms;

}

=item B<orac_loop_wait>

Waits for the specified file to appear in the directory.
A timeout of 12 hours is hard-wired in initially -- undef
is returned if the timeout is exceeded.

  $frm = orac_loop_wait($class, $utdate, \@list, $skip);

The first member of the array is used to keep track of the
current observation number. This element is incremented so that
the following observation is returned when the routine is called
subsequently. This means that this loop is similar to using the
'-from' option in conjunction with the 'inf' loop except that
new data is expected.

The loop will return undef (i.e. terminate looping) if the
supplied array contains undef in the first entry.

The skip flag is used to indicate whether the loop should skip
forward if the current observation number can not be found
but a higher numbered observation is present.

If no data can be found, the directory is scanned every few seconds
(hard-wired into the routine). A dot is printed to the screen after
a specified number of scans (default is 1 dot per scan and one scan every
2 seconds).

=cut

sub orac_loop_wait {
  #  print "in orac_loop_wait\n";
  croak 'Wrong number of args: orac_loop_wait(class, ut, arr_ref, skip)'
    unless scalar(@_) == 4;

  my ($class, $utdate, $obsref, $skip) = @_;

  # If obsno is undef return undef
  return unless defined $obsref->[0];

  # Get the obsno
  my $obsno = $obsref->[0];

  # Create a new frame in class
  my $Frm = $class->new;

  # Get the filename pattern.
  my $fname = $Frm->pattern_from_bits($utdate, $obsno);

  # If we actually have a pattern, crash out because we don't
  # want to deal with that situation. Tell the user to use some
  # other option like '-loop flag'.
  if ( ref( $fname ) eq 'Regexp' ) {
    orac_throw("Cannot run under '-loop wait' for this instrument.\nTry '-loop flag' instead.\n");
  }

  # Now check for the file
  orac_print("Checking for next data file: $fname");

  # Now loop until the file appears

  my $timeout = 43200;          # 12 hours timeout
  my $timer   = 0.0;
  my $pause   = 2.0;           # Time between checks
  my $dot     = 1;             # Number of pauses for each dot printed
  my $npauses = 0; # number of pauses so far (reset each time dot printed)

  # Get the full path to the filename
  my $actual = _to_abs_path( $fname );

  my $old = 0;                  # Initial size of the file


  # was looping with
  #  while (! -e $actual) {
  # Cant do a loop detecting $actual explicitly since this
  # doesnt allow for the copying time..
  while (1) {

    # Check if the file is there
    if (-e $actual) {

      # Now need to check the file size
      # This is needed as a kluge so that we will not try to
      # open a file that is in the process of being copied.
      # This assumes that the file length will not stay constant
      # over the length of our sleep.

      my $length = (stat $actual)[7];

      last if ($length == $old && $length > 0);
      # store the previous value
      $old = $length;

    } elsif ($skip) {

      # Okay the file was not there -- if SKIP is true we should re-read
      # the directory to check whether the next file has appeared
      # In order to prevent the problem of observations n and n+1 appearing
      # in the time it takes us to read the directory we should make sure
      # that we are looking for observation n (which has not turned up
      # yet) rather than n+1. We do this by running orac_check_data_dir
      # with an observation number one less than we are interested in

      # Run in a scalar context since we are only interested in the next
      # observation. The flag argument is set to 0.
      my $next = orac_check_data_dir($class, $obsno - 1, 0);

      # Check to see if something was found
      if (defined $next) {

        # This indicates that an observation iss available
        # Now need to modify the name of the file that the loop is
        # searching for ($actual) [this is done many times in the loop and
        # twice in this routine!]. Do not need to reset the timer since
        # we already know that we have a file.

        if ($next != $obsno) {

          orac_print ("\nFile $fname appears to be missing\n");

          # Okay - it wasnt the expected observation number
          $obsno = $next;
          $obsref->[0] = $obsno; # And set the array value

          # Create new filename. We can do this string concatenation
          # straight off because we know that pattern_from_bits()
          # won't return a regex, since we checked for that above.
          $actual = File::Spec->catfile($ENV{ORAC_DATA_IN},
                                        $Frm->pattern_from_bits($utdate,$next));

          orac_print("Next available observation is number $obsno");

          # Loop round
          next;
        }
      }
    }

    # Sleep for a bit
    $timer += orac_sleep($pause);
    $npauses++;

    # Return bad status if timer hits timeout
    if ($timer > $timeout) {
      orac_print "\n";
      orac_err("Timeout whilst waiting for next data file: $fname\n");
      return;
    }

    # Show that we are thinking
    # Print a dot every time $npauses equals the number specified in $dot
    # This is so that the checking cycle can be different from the dot
    # drawing cycle
    if ($npauses >= $dot) {
      orac_print ".";
      $npauses = 0;
    }

  }
  orac_print "\nFound\n";

  # The file has appeared
  # Link_and_read
  # A new $Frm is created and the file is converted to our base format (NDF).
  my @Frms = link_and_read($class, $utdate, $obsno, 0);

  # Now need to increment obsnum for next time round
  $$obsref[0]++;

  return @Frms;
}

=item B<orac_loop_flag>

Waits for the specified file to appear in the directory
by looking for the appearance of the associated flag file.
A timeout of 60 minutes is hard-wired in initially -- undef
is returned if the timeout is exceeded.

  $frm = orac_loop_flag($class, $utdate, \@list, $skip);

The first member of the array is used to keep track of the
current observation number. This element is incremented so that
the following observation is returned when the routine is called
subsequently. This means that this loop is similar to using the
'-from' option in conjunction with the 'inf' loop except that
new data is expected.


The loop will return undef (i.e. terminate looping) if the
supplied array contains undef in the first entry.

=cut

sub orac_loop_flag {
  #print "in orac_loop_flag\n";
  croak 'Wrong number of args: orac_loop_flag(class, ut, arr_ref, skip)'
    unless scalar(@_) == 4;

  my ($class, $utdate, $obsref, $skip) = @_;

  # If obsno is undef return undef
  return unless defined $obsref->[0];

  # Get the obsno
  my $obsno = $obsref->[0];

  # We use the second slot in the array to store the files read
  # previously for this observation number. If it is empty then
  # this is the first time through or the flag files are empty
  # and so can not possibly be re-read
  my $prev = $obsref->[1];
  $prev = [] unless defined $prev;

  # Create a new frame in class
  my $TemplateFrm = $class->new;

  # Construct the flag name(s) from the observation number
  my @fnames = $TemplateFrm->flag_from_bits($utdate, $obsno);

  # Determine how many observations to look ahead.
  my $lookahead = 0;

  # if our flag files contain pointers to multiple files then
  # in principal we are always one flag file behind. We always
  # have to look at $obsno and $obsno+1. If prev is defined we
  # need to look for the next one as well
  $lookahead += 1 if @$prev;

  # If "skip" is enabled, also look ahead several more observations.
  $lookahead += 10 if $skip;

  # Get the relevant string representing what we are looking for
  my $text;
  if (@fnames > 1) {
    $text = "$fnames[0] to $fnames[-1]";
  } else {
    $text = $fnames[0];
  }
  $text .= " and the next $lookahead flag file(s)" if $lookahead;
  orac_print("Checking for new data via flag: $text");

  # Now loop until the file appears

  my $timeout = 43200;          # 12 hour timeout
  my $timer   = 0.0;
  my $pause   = 2.0;            # Pause for 2 seconds
  my $dot     = 1;              # Number of pauses per dot
  my $npauses = 0; # number of pauses so far (reset each time dot printed)

  # Get a full path to the flag files
  my @actual = _to_abs_path( @fnames );

  # Check file size since that controls how we increment the observation
  # number
  my $nonzero;

  # Now that we are looking (possibly) for two sets of data files
  # we now must be in an infinite loop
  LOOP: while (1) {
    # if the requested obsnum is available we first need to compare
    # and contrast if we have a non zero size flag file
    if (_files_there(@actual )) {
      $nonzero = _files_nonzero( @actual );
      last unless $nonzero;

      # must be new if $prev is empty
      last unless @$prev;

      # read the file (should contain something)
      my @all = _read_flagfiles( @actual );

      # simply compare number of entries. Not very robust but good enough
      if (@all > @$prev) {
        orac_print "\nFound additional data associated with current observation...";

        last;
      }
    }

    # if the next observation, or one of the other future observations
    # for which we are looking, has turned up we run with it
    for (my $i = 1; $i <= $lookahead; $i ++) {
      # Dynamically regenerate the list of expected files for the observation
      # in question.  In the case of SCUBA-2 this will cause the meta file to
      # be read, which is necessary when not all sub-arrays are enabled.
      my @nactual = _to_abs_path($TemplateFrm->flag_from_bits($utdate,
                                                              $obsno + $i));

      if (_files_there(@nactual)) {
        # check file length
        $nonzero = _files_nonzero(@nactual);
        # increment the observation number
        $obsno += $i;
        # clear previous
        $prev = [];

        # Finish loop since we have found a file
        last LOOP;
      }
    }

    # Sleep for a bit
    $timer += orac_sleep($pause);
    $npauses++;

    # Return bad status if timer hits timeout
    if ($timer > $timeout) {
      orac_print "\n";
      orac_err("Timeout whilst waiting for next data file: $fnames[0]\n");
      return;
    }

    # Show that we are thinking
    # Print a dot every time $npauses equals the number specified in $dot
    # This is so that the checking cycle can be different from the dot
    # drawing cycle
    if ($npauses >= $dot) {
      orac_print ".";
      $npauses = 0;
    }

  }
  orac_print "\nFound data from observation $obsno\n";

  my $Frm;

  # The flag has appeared therefore we believe the file is there as well.
  # Link_and_read
  # A new $Frm is created and the file is converted to our base format (NDF).
  my @Frms;
  eval {
    # take a copy of $prev to prevent bizarre error if we get an error
    # and immediate retry
    my @local = @$prev;
    @Frms = link_and_read($class, $utdate, $obsno, 1, \@local);
    @$prev = @local;
  };
  if ( $@ || !defined $Frms[0] ) {
    # that failed. This may indicate a sync issue so pause
    # for a couple of seconds and retry without the eval
    ORAC::Error->flush;
    orac_warn "Error loading file for observation $obsno. Sleeping for 2 seconds...\n";
    orac_sleep(2);
    @Frms = link_and_read($class, $utdate, $obsno, 1, $prev);
  }
  ;

  # we can only increment the observation number if we are dealing
  # with non-zero length flag files
  if (!$nonzero) {
    $obsno++;
  }

  # store the new value
  $obsref->[0] = $obsno;

  # make sure the previous reads are stored
  # this will just be the contents of the flag files
  $obsref->[1] = $prev if $nonzero;

  return @Frms;

}

=item B<orac_loop_file>

Takes a list of files and returns back frame objects for the files,
removing them from the input array.

  @Frms = orac_loop_file($class, $ut, \@array, $skip );

undef is returned on error or if the list of files is empty.

The UT and skip parameters are ignored.

The input filenames are assumed to come from $ORAC_DATA_IN if they use
a relative path.

=cut

sub orac_loop_file {

  croak 'Wrong number of args: orac_loop_file($class, $ut, $arr_ref, $opt_skip)'
    unless scalar(@_) == 4;

  my ($class, $utdate, $obsref, $skip) = @_;

  my @fnames;
  while ( my $fname = shift @$obsref ) {

    # If filename is undef or a blank line skip to the next one.
    next unless defined $fname;
    next unless $fname =~ /\w/;
    orac_print( "Checking for next data file: $fname\n" );

    # If we have a relative path, assume it's relative to
    # $ORAC_DATA_IN.
    if ( ! File::Spec->file_name_is_absolute( $fname ) ) {
      $fname = File::Spec->catfile( $ENV{'ORAC_DATA_IN'}, $fname );
    }

    push @fnames, $fname;
  }

  return undef if ! scalar @fnames;

  my $Frm = $class->new;

  return _convert_and_link( $Frm, @fnames );

}

=item B<orac_loop_task>

In this scheme ORAC-DR looks for a flag file of a standard name created
by a task that is monitoring remote QL parameters and writing the
data locally. The flag file is always the same name and contains the
files that should be processed by the pipeline immediately.

When the pipeline finds a flag file the file is immediately renamed
and the listed files are then "owned" by the pipeline. The QL
task monitor will continue to write a new flag file when data arrives
and delete the old flag file if the pipeline has not taken ownership.
The QL task monitor deletes files that were never harvested. The
pipeline should tidy up for itself if it finds the flag file.

  $Frm = orac_loop_task( $class, $ut, \@array, $skip );

In this looping scheme all except the first argument are ignored.

=cut

sub orac_loop_task {
  croak 'Wrong number of args: orac_loop_task(class, ut, arr_ref, skip)'
    unless scalar(@_) == 4;
  my ($class, $ut, $arr, $skip ) = @_;

  orac_print("Checking for data from QL monitor task\n");

  # Flag file is fixed name
  my $flagfile = task_flag_file();
  my $tmpflag  = $flagfile . "_in_use";

  # Clean up any files associated with the old flag file
  # that are in the current directory.
  clean_flag_file_and_entries( $tmpflag );

  # Use dots and timeouts as for the other systems
  my $timeout = 43200;          # 12 hours timeout
  my $timer   = 0.0;
  my $pause   = 0.4; # Time between checks (do not divide into 1 exactly)
  my $dot     = 4;   # Number of pauses for each dot printed
  my $npauses = 0; # number of pauses so far (reset each time dot printed)

  # Now look for a flag file. Very simple flag file implementation
  while (1) {

    # To avoid a race condition with the monitor task we simply attempt
    # to rename the flag file to somewhere safe that we can open at our
    # leisure without risk that it will be renamed from under us
    if ( rename $flagfile, $tmpflag ) {
      last;
    }

    # Sleep for a bit
    $timer += orac_sleep($pause);
    $npauses++;

    # Return bad status if timer hits timeout
    if ($timer > $timeout) {
      orac_print "\n";
      orac_err("Timeout whilst waiting for next data file from the QL\n");
      return;
    }

    # Show that we are thinking
    # Print a dot every time $npauses equals the number specified in $dot
    # This is so that the checking cycle can be different from the dot
    # drawing cycle
    if ($npauses >= $dot) {
      orac_print ".";
      $npauses = 0;
    }

  }

  orac_print "\nFound data from remote task\n";

  # Read the files from the file
  my @files = _read_flagfiles( $tmpflag );

  if (!@files || !defined $files[0] ) {
    orac_err( "Could not find files in the monitored flag file.\n" );
    return;
  }

  my @frames = _convert_and_link( $class->new(), @files );

  # Override group membership decisions since we only
  # want to combine this data with data from the same
  # observation when in QL/Task mode
  for (@frames) {
    $_->group( $_->hdr("OBSNUM") );
  }

  # return the frame object
  return @frames;
}

=back

=head1 OTHER EXPORTED SUBROUTINES

=over 4

=item B<orac_check_data_dir>

Routine to check the input data directory (ORAC_DATA_IN) for
files in order to see whether files exist with a higher number
than the supplied number. The routine is supplied with a class name,
UT date and current observation number. An additional argument
is provided to determine whether data files or flag files should
be used for the directory search.

   $next = orac_check_data_dir($class, $current, $flag);
   ($next, $high) = orac_check_data_dir($class, $current, $flag);

If called in a scalar context, the return argument is the next
observation in the sequence. If called in an array context, two
arguments are returned: the next observation number and the highest
observation number.

undef (or undef,undef) is returned if no higher observations can be
found. If it is necessary to check for the existence of current
file as well (eg via a data detection loop) then simply decrement the
supplied argument by 1.

This routine is used in conjunction with the -from loop (where we
dont know the end) and the waiting loops where we are not sure whether
new data have been written to disk but missing the next observation.

This routine does NOT look in ORAC_DATA_OUT.

A global variables (@LIST) is used to speed up the sorting by storing
a list of observation numbers that have previously been shown to have a lower
number than required (NOT YET IMPLEMENTED).

=cut

sub orac_check_data_dir {

  croak 'Usage check_data_dir(ClassName, CurrentObs, Flag)'
    unless scalar(@_) == 3;

  my ($class, $obsnum, $flag) = @_;

  # Create a new dummy Frame
  my $DummyFrm = $class->new();

  # Now retrieve the pattern

  # The most general implementation (and most robust) would
  # be to query the frame object for a pattern that can be used
  # to match files.
  # For now, we will make a guess at the pattern. This could
  # throw us off the scent in some special cases [eg the directory
  # contains more than one night of data, DR files which match
  # the generic pattern....]
  # If FLAG is true then we simply search for the dot files with
  # a .ok at the end

  # SCUBA does not have .ok

  my $pattern;

  if ($flag) {
    # This only works for flag files that end in .ok
    # so get a dummy flag file
    my @dflags = $DummyFrm->flag_from_bits('p',1);
    if ($dflags[0] =~ /\.ok$/) {
      $pattern = '\.ok$';       # ' - dummy quote for emacs colour
    } else {
      # look for a hidden file that starts with a . and has
      # the fixed part string in it
      my $f = $DummyFrm->rawfixedpart;
      $pattern = '^\..*'.$f;
    }

  } else {

    # We are matching data files. Try to match a string that
    # contains the fixed part and ends with the suffix.
    # (something like UFTI with a single character fixed part
    # may be tricky). Cant match the UT date since I dont know
    # where the UT fits into the filename convention

    $pattern = $DummyFrm->rawfixedpart . '.*' .
      $DummyFrm->rawsuffix . '$'; # ' dummy quote again

  }

  # Now open the directory
  opendir(my $DATADIR, "$ENV{ORAC_DATA_IN}")
    or die "Error opening ORAC_DATA_IN: $!";

  # Read the directory, extract the number and sort the list
  # Note that I dont even keep the filenames, just the numbers.
  # Do this with a sort/grep/map/grep combination which also filters
  # out observation numbers which aren't greater than the current observation.

  my @sort = sort { $a <=> $b }
    grep { $_ > $obsnum }
      map { $DummyFrm->raw($_); $DummyFrm->number }
        grep { /$pattern/ } readdir($DATADIR);

  # Close data directory
  closedir $DATADIR;

  # If the list isn't empty, the first item is the next observation.

  my $next = @sort ? $sort[0] : undef;

  # If we are in a scalar context we also need the highest number found
  # The highest value is the last member unless $next
  # is undef (meaning we got to the end of the list without finding
  # a higher value)

  if (wantarray) {
    my $highest = undef;
    $highest = $sort[-1] if defined $next;
    return ($next, $highest);

  } else {
    # We are in a scalar context - just return the next value
    return $next;

  }

}

=back


=head1 PRIVATE SUBROUTINES

The following subroutines are not exported.

=over 4

=item B<link_and_read>

General subroutine for converting ut and number into file
and creating a Frame object or multiple frame objects (depending
on instrument and mode).

  @frm = link_and_read($class, $ut, $obsnum, $flag)

  @frm = link_and_read($class, $ut, $obsnum, $flag, \@reflist)

The five parameters are:

=over 8

=item class

Class of Frame object

=item ut

UT date in YYYYMMDD

=item obsnum

Observation number

=item flag

If filename(s) is to come from flag file

=item reflist

Reference to array of files names that should be excluded from
the list of files read from the flag files (if flag files are non-zero).
This allows for flag files that can change length during an observation
(potentially allowing the pipeline to stop before the full observation
is complete but after data files start appearing for the observation).
The contents of this array are updated on exit to include the files that
were just read. This allows the reference list to be resubmitted
to this routine.

=back

Empty list is returned on error.

Returns 1 or more configured frame objects on success.

=cut

sub link_and_read {

  croak 'Wrong number of args: link_and_read(class, ut, num, flag)'
    if (scalar(@_) != 4 && scalar(@_) != 5);

  my ($class, $ut, $num, $flag, $reflist) = @_;

  # create the new frame object that will receive the files
  my $Frm = $class->new();

  my @flagnames;
  if ( $flag ) {

    # Get the flagname(s).
    @flagnames = _to_abs_path( $Frm->flag_from_bits($ut, $num) );

  }

  # List for raw filenames.
  my @names;

  # If we have a flagfile and it's non-zero size...
  if ( $flag && &_files_nonzero(@flagnames) ) {

    @names = _read_flagfiles( @flagnames );

    # now remove any files that were in the reference list.
    # compare with previous values (use a hash)
    if (defined $reflist) {

      # this will remove duplicate files from the flag file as well.
      # Not a problem in real life but may be a problem with faked
      # flag files
      my %all = map { $_, undef } @names;
      my %old = map { $_, undef } @$reflist;
      @names = grep { !exists $old{$_} } keys %all;

      if (!@names) {
        orac_err "Internal error reading flag file. No new filenames detecting in flag file. This should not happen by this stage";
        return;
      }

      # now update the reference list
      @$reflist = keys %all;

    }

  } else {

    my $pattern = $Frm->pattern_from_bits( $ut, $num );
    @names = _find_from_pattern( $pattern );

  }

  # Check if we actually have files.
  if ( ! defined( $names[0] ) ) {
    orac_err("Could not find files for observation $num. Aborting.\n");
    return;
  }

  # Now we need to convert the files
  # and/or link them to ORAC_DATA_OUT and configure the corresponding
  # frame object
  return _convert_and_link( $Frm, @names );
}

=item B<orac_sleep>

Pause the checking for new data files by the specified number of seconds.

  $time = orac_sleep($pause);

Where $pause is the number of seconds to wait and $time is the number
of seconds actually waited. Seconds can be fractional.

If the Tk system is loaded this routine will actually do a Tk event loop
for the required number of seconds. This is so that the X screen will
be refreshed. Currently the only test is the Tk is loaded, not that
we are actually using Tk.....

=cut

sub orac_sleep {

  my $pause = shift;
  my $actual;

  # Define our reference time
  my $now = Time::HiRes::time();

  if (defined &Tk::DoOneEvent) {
    # Tk friendly....
    while (Time::HiRes::time() - $now < $pause) {
      # Process events (Dont wait if there were none)
      &Tk::DoOneEvent(&Tk::DONT_WAIT);

      # Pause for a fraction of a second to stop us going into
      # a CPU intensive loop for no reason Not the best solution since
      # it does make the Tk events a bit unresponsive
      select undef,undef,undef,0.2;

    }

  } else {
    # We want to allow fractional sleeps so use select
    select undef,undef,undef,$pause;

  }

  # Calculate actual elapsed time
  $actual = Time::HiRes::time() - $now;

  return $actual;

}

=item B<_find_from_pattern>

Given a pattern or string, look in ORAC_DATA_IN and return all the files
that are applicable.

  @files = _find_from_pattern( $pattern );

If the pattern finds .ok files they will be opened. It is assumed that this
routine will not be triggered in dynamic flag mode.

=cut

sub _find_from_pattern {
  my $pattern = shift;

  my @files;
  if ( ref( $pattern ) eq 'Regexp' ) {

    # If we have a regular expression, find all the files that match
    # that pattern.
    find sub { my $file = $_; push @files, $File::Find::name if ( $file =~ /$pattern/ ) }, $ENV{'ORAC_DATA_IN'};

    my @new;
    for my $f (@files) {
      if ( $f =~ /\.ok/) {
        push(@new, _read_flagfiles($f));
      } else {
        push(@new, $f);
      }
    }
    @files = @new;

  } else {

    # We have a string returned from pattern_from_bits() so assume
    # that that's a filename. Just check to see if that file exists.
    my $file = File::Spec->catfile($ENV{ORAC_DATA_IN},$pattern);
    push(@files, _to_abs_path($file)) if -e $file;
  }

  return @files;
}

=item B<_files_there>

Return true if all the specified files are present.

 if (!_files_there( @files ) {
   ...
 }

Returns false is no files are supplied.

=cut

sub _files_there {
  return 0 unless @_;
  for my $f (@_) {
    return 0 unless -e $f;
  }
  return 1;
}

=item B<_files_nonzero>

Return true if all the specified files are present with
a size greater than 0 bytes

 if (_files_nonzero( @files ) {
   ...
 }

Returns false if no files are supplied.

=cut

sub _files_nonzero {
  return 0 unless @_;
  for my $f (@_) {
    return 0 unless -s $f;
  }
  return 1;
}

=item B<_to_abs_path>

Convert a filename(s) relative to ORAC_DATA_IN to an absolute path.

  @abs = _to_abs_path( @rel );

Does not affect absolute paths.

In scalar context, returns the first path.

=cut

sub _to_abs_path {
  my @out = map { $_ = _clean_path(File::Spec->catfile( $ENV{ORAC_DATA_IN}, $_ ))
                    unless File::Spec->file_name_is_absolute($_);
                  $_;
                } @_;
  return (wantarray ? @out : $out[0] );
}

=item B<_clean_path>

Splits path up and resolves "../" entries. This is done because normally if you
use a symlink ../ ends up on the other end of the directory symlink.

 $clean = _clean_path( $notclean );

This may be dangerous....

=cut

sub _clean_path {
  my $dirty = shift;
  my ($vol, $dir, $file) = File::Spec->splitpath( $dirty );
  my @dirs = File::Spec->splitdir($dir);
  my @outdirs;
  for my $d (@dirs) {
    if ($d eq '..') {
      # remove last entry from dir list unless the last entry
      # is a relative path identifier or root dir
      if (@outdirs && $outdirs[-1] ne ".." && $outdirs[-1] ne "."
          && $outdirs[-1] ne "") {
        pop(@outdirs);
      } else {
        push(@outdirs, $d);
      }
    } elsif ($d eq '.') {
      # ignore it unless we are first entry
      if (!@outdirs) {
        push(@outdirs, $d);
      }

    } else {
      # Store it
      push(@outdirs, $d);
    }
  }
  return File::Spec->catpath( $vol, File::Spec->catdir(@outdirs), $file);
}

=item B<_convert_and_link>

Given the supplied file names, convert and link each file to ORAC_DATA_OUT.
If successful returns a list of C<ORAC::Frame> objects derived from the input frame.

  @frames = _convert_and_link( $Frm, @files );

=cut

sub _convert_and_link {
  my $Frm = shift;
  my @names = @_;

  if (!@names) {
    orac_err("Can not convert/link 0 files!");
    return;
  }

  # Read the input and output formats from the Frame object.
  my $infmt = $Frm->rawformat;
  my $outfmt = $Frm->format;

  # convert the files
  my @bname = _convert_and_link_nofrm( $infmt, $outfmt, @names );
  return unless @bname;

  return $Frm->framegroup( @bname );

}


=item B<_convert_and_link_nofrm>

This is the low level file conversion/linking routine used by
C<_convert_and_link>.

  @converted = _convert_and_link_nofrm( $infmt, $outfmt, @input);

Given an input and output format and a list of files, returns
the modified files. Returning an empty list indicates an error (but
only if @input contained some filenames).

=cut

sub _convert_and_link_nofrm {
  my ($infmt, $outfmt, @names) = @_;
  return unless @names;

  # Sort the list.
  @names = sort @names;

  # Right. Now we have a list of raw filenames in @names. These filenames
  # include the full path to the file.

  # Deal with conversion of files.
  unless ( defined $CONVERT ) {
    $CONVERT = new ORAC::Convert;
  }

  # Convert the files.
  my @cname;
  my @bname;
  foreach my $file ( @names ) {

    # Remember, $file here is relative to $ORAC_DATA_IN...
    chomp($file);
    orac_print "Converting $file from $infmt to $outfmt...\n"
      if $infmt ne $outfmt;

    # If the file is missing but not expected to be gzipped,
    # check whether a gzipped copy is present.  This allows
    # ORAC-DR to be run on data which has been gzipped without
    # having to edit the OK files.  Unfortunately this requires
    # using -e just before convert() does so again, because
    # it's this module which currently handles ungzipping.
    # Should there be a switch required to enable this check?
    if ($file !~ /\.gz$/ and ! grep {$_ eq $file . '.gz'} @names
            and  ! -e $file and -e $file . '.gz') {
        orac_warn("$file is unexpectedly gzipped!\n");
        $file .= '.gz';
    }

    # The input file might be gzipped, so copy it over and unzip it.
    if( $file =~ /\.gz$/ ) {
      orac_print "Unzipping $file...";
      my $out = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, basename( $file ) );
      $out =~ s/\.gz$//;
      if( ! -e $out ) {
        gunzip $file => $out or orac_throw "gunzip failed: $GunzipError\n";
        orac_say "done.";
      } else {
        orac_say " file already exists in ORAC_DATA_OUT!"
      }
      $file = $out;
    }

    # we still do the conversion even if the formats are the same
    # because convert() propogates the file from DATA_IN to DATA_OUT
    # via a symlink
    my( $infile, $outfile ) = $CONVERT->convert( $file,
                                                 { IN => $infmt,
                                                   OUT => $outfmt,
                                                   OVERWRITE => 0
                                                 });

    if (!defined $outfile) {
      orac_err("Failed to convert $infile. Aborting.\n");
      return ();
    }

    # $outfile at this point is relative to $ORAC_DATA_OUT.
    push @cname, $outfile;
    push @bname, basename( $outfile );
  }

  # Check to make sure we've converted them all, or if we
  # don't have any converted files at all.
  # This test can be removed now that the loop aborts the first
  # time a conversion fails.
  # The test is also incorrect since it should have been testing
  # definedness for all of @cname. We can keep this test if the
  # loop does not store the output filename in @cname if it is
  # not defined
  if ( ( scalar(@cname) != scalar(@names) ) || ( ! defined( $cname[0] ) ) ) {
    orac_err("Error in data conversion tool\n");
    return ();
  }

  # Try to do this in a more structured way so that we can tell
  # Why something fails

  # If the file exists in the current directory then we dont care
  # what happens (eg it has been converted or a link of the correct
  # name exists with a file at the other end

  # We have to make sure the file is here else the Frame configuration
  # will not work correctly.
  foreach my $fname ( @cname ) {

    # We do this because the basename will be...
    my $bname = basename($fname);

    unless (-e $bname) {

      # Now check in the ORAC_DATA_IN directory to make sure it is there
      unless (-e _to_abs_path( $fname ) ) {
        orac_err("Requested file ($fname) can not be found in ORAC_DATA_IN\n");
        return ();
      }

      # Now if there is a link already in ORAC_DATA_OUT we need to
      # read it to find out where it is pointing (we will only get
      # to this point if the link does not point to anything at the
      # other end since -e follows links
      if (-l $bname) {
        my $nowhere = readlink($bname);
        unless (defined $nowhere) {
          orac_err("Error reading through link from ORAC_DATA_OUT/$fname:\n");
          orac_err("$!\n");
        } else {
          orac_err("File $fname does exist in ORAC_DATA_OUT but is a link\n");
          orac_err("pointing to nowhere. It points to: $nowhere\n");
        }
        return ();
      }

      # Now we should try to create a symlink and say something
      # if it fails
      symlink(File::Spec->catfile($ENV{ORAC_DATA_IN},$fname), $bname) ||
        do {
          orac_err("Error creating symlink named $bname from ORAC_DATA_OUT to '".
                   File::Spec->catfile($ENV{ORAC_DATA_IN},$fname). "'\n");
          orac_err("$!\n");
          return ();
        };

      # Note that -e checks through symlinks
      # This final check SHOULD work else something really wacky is
      # going on
      unless (-e $bname) {
        orac_err("File ($fname) can not be found through link from\n");
        orac_err("ORAC_DATA_OUT to ORAC_DATA_IN\n");
        return ();
      }

    }

  }

  return @bname;
}

=item B<_read_flagfiles>

Read the specified flag files and return the contents.

=cut

sub _read_flagfiles {
  my @flagnames = @_;

  my @names;
  for my $flagname (@flagnames) {
    open( my $flagfile, "<", $flagname )
      or orac_throw "Unable to open flag file $flagname: $!";

    # Read the filenames from the file.
    push @names, [grep /\w/, <$flagfile>];

    # Close the file.
    close $flagfile
      or orac_throw "Error closing flag file $flagname: $!";
  }

  my @allnames;
  unless ($read_flag_sync) {
    @allnames = (map {@$_} @names);
  }
  else {
    my $min_last = min(map {$#$_} @names);
    @allnames = (map {@{$_}[0 .. $min_last]} @names);
  }

  chomp @allnames;

  # add $ORAC_DATA_IN to path if not absolute
  return _to_abs_path( @allnames );
}

=back

=head2 QL Monitor Support

Routines to support "task" mode and the "qlgather" task
monitor.

=over 4

=item B<_task_flag_file>

Name of flag file to monitor in task mode. Includes
full path.

  $flag = task_flag_file();

=cut

sub task_flag_file {
  return File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "oracdr_qlfiles.ok");
}

=item B<_is_in_data_out>

If the file is present in ORAC_DATA_OUT the name in
ORAC_DATA_OUT is returned. Otherwise returns undef. The
ORAC_DATA_OUT version of the filename is returned
so that a soft link can be detected by the caller even
if the file supplied to this routine points to a file
outside ORAC_DATA_OUT.

  $file_in_data_out = _is_in_data_out( $file );

Can include a full path. ORAC_DATA_OUT will be prepended
if the file name is not absolute.

=cut

sub _is_in_data_out {
  my $testfile = shift;
  return unless defined $testfile;

  # if the filename we are given is not absolute we still
  # can not know for sure that the file is in ORAC_DATA_OUT
  # because a relative path can include directories.
  $testfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, $testfile )
    unless File::Spec->file_name_is_absolute( $testfile );

  # no use trying if the file is not there
  return unless -e $testfile;

  # work out the file name
  my ($vol, $dir, $filename) = File::Spec->splitpath( $testfile );

  # then place it in ORAC_DATA_OUT
  my $cmpfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, $filename );
  return unless -e $cmpfile; # is not in ORAC_DATA_OUT

  # and compare the two using stat (which reads through soft links)
  my @oristat = stat($testfile);
  my @cmpstat = stat($cmpfile);

  for my $field ( qw/ 0 1 2 3 4 5 6 7 9 10 11 12 / ) {
    if ( $oristat[$field] != $cmpstat[$field]) {
      return;
    }
  }
  return $cmpfile; # are the same so return the comparison path
}

=item B<clean_flag_file_and_entries>

Read the supplied flag file and remove any files that
are listed and in $ORAC_DATA_OUT. Then remove the flag
file itself.

  clean_flag_file_and_entries( $file );

=cut

sub clean_flag_file_and_entries {
  my $file = shift;
  return unless -e $file;

  my @contents = _read_flagfiles( $file );

  for my $f (@contents) {
    my $path_in_data_out =  _is_in_data_out( $f );
    next unless $path_in_data_out;
    unlink $path_in_data_out;
  }
  unlink $file;
}

=back

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007-2009, 2011 Science and Technology Facilities Council.
Copyright (C) 1998-2006 Particle Physics and Astronomy Research
Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
