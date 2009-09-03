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

# Validate the data directories
ORAC::Inst::SetupEnv::orac_validate_datadirs( \%env );

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

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

Copyright (C) 2009 Science and Technology Facilities Council.
All Rights Reserved.

=cut
