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

=head1 DESCRIPTION

This module provides simple perl functions that are not available
from standard perl. These are available to all ORAC primitive writers
(although there is no reason why this has to be ORAC specific).

=cut

require Exporter;
@ISA = (Exporter);
@EXPORT = qw( max min log10 nint utdate);

use Carp;
use strict;
use vars qw/$VERSION/;
$VERSION = undef; # -w protection
$VERSION = '0.10';

# Use POSIX so that I can get log10 support
# I realise that I can create a log10 function via natural logs
use POSIX qw/log10/;


=head1 SUBROUTINES

=over 4

=item min(ARRAY)

Find the minimum value of an array. Can also be used to find
the minimum of a list of scalars since arguments are passed into
the subroutine in an array context.

  $min = min(@values);
  $min = min($a, $b, $c);

=cut

sub min {
  my (@z) = @_;
  my ($zmin) = $z[$[];
  my @min = grep((($_ <= $zmin) && ($zmin = $_)),@z);
  ($#min == -1) && push(@min,$zmin);
  my $answer = $min[$#min];
}

=item max(ARRAY)

Find the maximum value of an array. Can also be used to find
the maximum of a list of scalars since arguments are passed into
the subroutine in an array context.

  $max = max(@values);
  $max = max($a, $b, $c);

=cut

sub max {
  my (@z) = @_;
  my ($zmax) = $z[$[];
  my @max = grep((($_ >= $zmax) && ($zmax = $_)),@z);
  ($#max == -1) && push(@max,$zmax);
  my $answer =  $max[$#max];
}


=item log10(scalar)

Returns the logarithm to base ten of a scalar.

  $value = log10($number);

Currently uses the implementation of log10 found in the
POSIX module


=cut


sub log10 {

  my $in = shift;

  return POSIX::log10($in);
}


=item nint()

Return the nearest integer to a supplied floating point
value. 0.5 is rounded up.

=cut

sub nint {
  my $value = shift;

  return int($value + 0.5);

}

=item utdate

Return the UT date (strictly, GMT) date in the format yyyymmdd

=cut

sub utdate {
 
my ($day,$month,$year) = (gmtime)[3..5];
$month++;
$year += 1900;
my $yyyymmdd = $year . '0'x (2-length($month)) . $month . '0'x (2-length($day)) . $day;

}


=back

=head1 SEE ALSO

L<POSIX>

=head1 AUTHORS

Frossie Economou  (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)

=cut
