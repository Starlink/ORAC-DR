package ORAC::General;

=head1 NAME

ORAC::General - Simple perl subroutines that may be useful for primitives

=head1 SYNOPSIS

  use ORAC::General;

  $max = max(@values);
  $min = min(@values);
  $result = log10($value);
  $result = nint($value);
  $yyyymmdd = utdate;
  %hash = parse_keyvalues($string);
  @obs = parse_obslist($string);

=head1 DESCRIPTION

This module provides simple perl functions that are not available
from standard perl. These are available to all ORAC primitive writers,
but they are general in nature and have no connection to orac. Some of
these are used in the ORAC infastructure, so ORACDR does require this
library in order to run.


=cut

require Exporter;
@ISA = (Exporter);
@EXPORT = qw( max min log10 nint utdate parse_keyvalues parse_obslist);

use Carp;
use warnings;
use strict;
use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


# Use POSIX so that I can get log10 support
# I realise that I can create a log10 function via natural logs
use POSIX qw//;


=head1 SUBROUTINES

=over 4

=item B<min>

Find the minimum value of an array. Can also be used to find
the minimum of a list of scalars since arguments are passed into
the subroutine in an array context.

  $min = min(@values);
  $min = min($a, $b, $c);

=cut

sub min {
  my $zmin = $_[0];
  foreach (@_) {
    ($_ < $zmin) && ($zmin = $_);
  }
  return $zmin;
}

=item B<max>

Find the maximum value of an array. Can also be used to find
the maximum of a list of scalars since arguments are passed into
the subroutine in an array context.

  $max = max(@values);
  $max = max($a, $b, $c);

=cut

sub max {
  my $zmax = $_[0];
  foreach (@_) {
    ($_ > $zmax) && ($zmax = $_);
  }
  return $zmax;
}


=item B<log10>

Returns the logarithm to base ten of a scalar.

  $value = log10($number);

Currently uses the implementation of log10 found in the
POSIX module


=cut


sub log10 {

  my $in = shift;

  return POSIX::log10($in);
};


=item B<nint>

Return the nearest integer to a supplied floating point
value. 0.5 is rounded up.

=cut

sub nint {
  my $value = shift;

  return int($value + 0.5);

};

=item B<utdate>

Return the UT date (strictly, GMT) date in the format yyyymmdd

=cut

sub utdate {

  my ($day,$month,$year) = (gmtime)[3..5];
  $month++;
  $year += 1900;
  my $yyyymmdd = $year . '0'x (2-length($month)) . $month . '0'x (2-length($day)) . $day;

}

=item B<parse_keyvalues>

Takes a string of comma-separated key-value pairs and return a hash.

  %hash = parse_keyvalues("a=1,b=2,C=3");

The keys are down-cased.

=cut


sub parse_keyvalues {

  my ($string) = shift;
  my %hash;
  my @pairs = split(',',$string);

  foreach my $pair (@pairs) {
    my ($key,$value) = split('=',$pair,2);
    $key = lc($key);
    $hash{$key} = $value;
  };

  return %hash;
}


=item B<parse_obslist>

Converts a comma separated list of observation numbers (as supplied
on the command line for the -list option) and converts it to
an array of observation numbers. Colons are treated as range arguments.

For example,

   "5,9:11"

is converted to

   (5,9,10,11) 

=cut

# Argument disentanglement

# Parse the observation list that is entered with the -list
# option. This is a comma separated list of numbers.
# Ranges can be specified with colons

# Returns an array of observation numbers.

sub parse_obslist {

  my $obslist = shift;
  my @obs = ();

  # Split on the comma
  @obs = split(",",$obslist);

  # Now go through each entry and see if we can expand on :
  # a:b expands to a..b.
  for (my $i = 0; $i <= $#obs; $i++) {

    $obs[$i] =~ /:/ && do {
      my ($start, $end) = split ( /:/, $obs[$i]);

      # Generate the range
      my @junk = $start..$end;

      # Splice into @obs
      splice(@obs, $i, 1, @junk);

      # Increment the counter to take into account the
      # new additions (since we know that @junk does not contain
      # colons. We dont need this - especially if we want to parse
      # The expanded array
      $i += $#junk;

    }

  }

  return @obs;
}






=back

=head1 SEE ALSO

L<POSIX>,
L<List::Util>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt> and
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut
