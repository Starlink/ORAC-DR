#!perl

=head1 NAME

setup_oracdr_env.pl - Obtain the default environment parameters required to run ORAC-DR

=head1 SYNOPSIS

  set values=`starperl setup_oracdr_env.pl csh`
  eval $values

  set values=`starperl setup_oracdr_env.pl csh 20090814`

  starperl setup_oracdr_env.pl -debug csh 20090814
  starperl setup_oracdr_env.pl -debug -eng csh 20090814

=head1 DESCRIPTION

Calls routines in ORAC::Inst::SetupEnv to determine suggested settings
for the ORAC-DR environment variables and command alias. Returns
bash or c-shell code suitable for evaluation in the appropriate shell.
Usually called by the orac-dr initialisation shell scripts.

=head1 OPTIONS AND ARGUMENTS

=over 4

=item * shell

The shell type is the only non-option argument. Must be either
"bash" or "csh". Defaults to "csh".

=item * ut

Specifies the UT date. Default to today if not used. Is a primary
argument and not a "-" option so that we can pass $1 in directly
from the shell since oracdr_xxx initialisation scripts do not use
command-line option syntax. Shell mode must be supplied when specifying
a UT.

=item * -eng

Run in engineering mode. Usually means that alternate
date directories are used.

=item * -drmode

For pipelines that support it, switch to alternative reduction
mode. "SUMMIT" and "QL" are supported by some instruments.

=item * --help

Report some help information.

=item * --man

Show the man page.

=item * --debug

Add debugging information. Resultant output should not be
given to the shell for evaluation.

=back

=cut

use strict;
use warnings;
use File::Spec;

BEGIN {
  # Check environment variables.
  if( ! defined( $ENV{'ORAC_DIR'} ) ) {
    die "ORAC_DIR environment variable not set!";
  }
  if( ! defined( $ENV{'ORAC_PERL5LIB'} ) ) {
    $ENV{'ORAC_PERL5LIB'} = File::Spec->catfile( $ENV{'ORAC_DIR'}, "lib", "perl5" );
  }

  # For code reuse we need to load an ORAC module
  eval "use lib qw| $ENV{ORAC_PERL5LIB} |;";

}

use Getopt::Long;
use Pod::Usage;
use ORAC::Inst::SetupEnv;

# Handle arguments.
my ($help, $man, $debug, $eng, $drmode);
my $opt_status = GetOptions( "help" => \$help,
                             "man" => \$man,
                             "debug" => \$debug,
                             "eng" => \$eng,
                             "drmode=s" => \$drmode,
                           );
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;


my $shell = "CSH";
$shell = uc( shift(@ARGV) ) if @ARGV;
my $ut = shift(@ARGV);

my %env = ORAC::Inst::SetupEnv::orac_calc_instrument_settings( $ENV{ORAC_INSTRUMENT},
                                                               eng => $eng,
                                                               mode => $drmode,
                                                               ut => $ut);

# List of instrument-agnostic variables to send back.
my @orac_envs = qw/ ORAC_PERL5LIB /;

# ...and the instrument-agnostic ones too.
foreach my $oracenv ( @orac_envs ) {
  my $line = env2shell( $shell, $oracenv, $ENV{$oracenv} );
  print "$line";
  print "\n" if $debug;
}

# Build up an argument string for oracdr alias
my $oracdr_args = '';
if (exists $env{args}) {
  for my $k (keys %{$env{args}}) {
    $oracdr_args .= "$k ";
    $oracdr_args .= $env{args}->{$k}. " " if defined $env{args}->{$k};
  }
  print "ORAC-DR arguments = '$oracdr_args'\n" if $debug;

  # And for now write this out as a shell variable
  print toshellvar( $shell, "oracdr_args", $oracdr_args );
}

# Cache current working directory
my $curdir = File::Spec->rel2abs( File::Spec->curdir );

# Check the data directories and suggest alternatives if available
my $newin = checkdir( $env{ORAC_DATA_IN} );
my $newout = checkdir( $env{ORAC_DATA_OUT} );

if ( ! defined $newin ) {
  print STDERR "Unable to locate a raw data directory. Please fix ORAC_DATA_IN\n";
}

if ( ! defined $newout ) {
  print STDERR "Default output directory does not exist. Assuming current directory.\n";
  $env{ORAC_DATA_OUT} = $curdir;
}

if (defined $newin && defined $newout) {
  # if input and output are the same, we are not really
  # sure which one to use. This would usually indicate that
  # we found a UT date directory in the current directory

  # How clever do we want to be?
  if ($newin eq $newout) {
    my $usein;   # use it as input directory
    my $useout;  # use it as output directory
    opendir my $dh, $newin or die "Could not read directory $newin: $!\n";
    my @files = readdir( $dh );
    # these are all just guesses. .sdf can be in either directory in reality
    if (scalar grep /\.ok$/, @files) {
      # this is an input directory.
      $usein = 1;
    } elsif (scalar grep /^(\.orac|index)/, @files) {
      # has pipeline files in it
      $useout = 1;
    } else {
      # if we were really clever we would ask the ORAC::Frame class to see if there
      # are a few files in the directory that it recognizes
    }

    if ($usein) {
      $env{ORAC_DATA_IN} = $newin;
      $env{ORAC_DATA_OUT} = $curdir;
      print STDERR "ORAC_DATA_OUT does not exist. Using current working directory.\n";
    } elsif ($useout) {
      $env{ORAC_DATA_OUT} = $newout;
      print STDERR "ORAC_DATA_IN does not exist. Please set before running pipeline.\n";
    } else {
      $env{ORAC_DATA_OUT} = $curdir;
      $env{ORAC_DATA_IN} = $newin;
      print STDERR "ORAC_DATA_OUT does not exist. Using current working directory.\n";
      print STDERR "ORAC_DATA_IN does not exist. Guesing but please set before running pipeline.\n";
    }

  } else {
    # assume these are the right ones
    $env{ORAC_DATA_IN} = $newin;
    $env{ORAC_DATA_OUT} = $newout;
  }
}

# Warn people if ORAC_DATA_OUT looks like it is going to be a NFS mounted
# disk.
my $is_nfs = ORAC::Inst::SetupEnv::is_nfs_disk( $env{ORAC_DATA_OUT} );
if ($is_nfs) {
  print STDERR "***************************************************\n";
  print STDERR "***************************************************\n";
  print STDERR "* Your ORAC_DATA_OUT is not local to your machine  \n";
  print STDERR "* If you intend to run ORAC-DR you should be       \n";
  print STDERR "* using $is_nfs instead, which is where            \n";
  print STDERR "* $env{ORAC_DATA_OUT} is located                   \n";
  print STDERR "***************************************************\n";
  print STDERR "***************************************************\n";
}

# Print out the environment variable settings.
# ORAC_CAL_ROOT and ORAC_DATA_ROOT should not be set because
# they can make it difficult to switch instruments
foreach my $key ( keys %env ) {
  next if $key eq 'args';
  next if $key eq 'ORAC_CAL_ROOT';
  next if $key eq 'ORAC_DATA_ROOT';
  my $line = env2shell( $shell, $key, $env{$key} );
  print "$line";
  print "\n" if $debug;
}

exit;

# Convert an environment variable key and value to shell
# specific version
sub env2shell {
  my $s = uc(shift);
  my ($k, $v) = @_;
  if ($s eq 'CSH') {
    return "setenv $k '$v' ; ";
  } elsif ($s eq 'BASH') {
    return "export $k='$v' ; ";
  } else {
    die "Unrecognized shell: $s\n";
  }
  return;
}

# Convert the supplied variable name and value to a shell
# variable
sub toshellvar {
  my $s = uc(shift);
  my ($k, $v ) = @_;
  if ($s eq 'CSH') {
    return "set $k='$v' ; ";
  } elsif ($s eq 'BASH') {
    return "$k='$v' ; ";
  } else {
    die "Unrecognized shell: $s\n";
  }
  return;
}

# Checks to see if the directory exists. If it doesn't then starting
# from the bottom up it looks in the current directory to see whether
# parts of that tree are present locally
#   $dir = checkdir( $dir );
# Returns a new (or the old) path if one is found, returns undef
# if nothing suitable was located.

sub checkdir {
  my $dir = shift;

  return $dir if -d $dir;

  my @dirs = File::Spec->splitdir( $dir );

  # Try the smallest part first and then augment
  my @test;
  while ( my $next = pop(@dirs) ) {
    unshift( @test, $next ); # put on to front
    my $new = File::Spec->catdir( File::Spec->curdir, @test );
    return File::Spec->rel2abs( $new ) if -d $new;
  }
  return;
}

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

Copyright (C) 2009 Science and Technology Facilities Council.
All Rights Reserved.

=cut
