#!perl

# Test ORAC::General

use strict;
use warnings;
use Test::More tests => 38;



BEGIN { use_ok('ORAC::General', qw/ max min log10 nint utdate
  parse_keyvalues parse_obslist /) };


# First test max and min

my @testing = ( -20, 52, 0, 1, 1);

print "# Min/Max\n";

is(max(@testing), 52);
is(min(@testing), -20);
is(min(0,1,2), 0);
is(max(-20,-10,0), 0);

print "# NINT\n";

is(nint(5.5), 6);
is(nint(5.9), 6);
is(nint(5), 5);
is(nint(5.49),5);


print "# log10\n";

is(log10(100), 2);
is(log10(0.1), -1);

print "# utdate\n";

# We basically have to reimplement the utdate function!!!!!
# This is actually shorter than utdate()!
my @time = gmtime();
$time[5] += 1900;
$time[4]++;
my $now = sprintf("%04d%02d%02d", $time[5], $time[4], $time[3]);

is(utdate(), $now);


print "# parse_keyvalues\n";

my %keyvals = parse_keyvalues("X=22,Y=hello,Z=[-22]");

is($keyvals{x}, 22);
is($keyvals{y}, "hello");
is($keyvals{z}, -22);

# slightly harder
%keyvals = parse_keyvalues('file=blah,curly={c,d},range="a,b",oopsy=[22],oops=22,unquot=1,2,wow=c,d,e');

is($keyvals{file},"blah");
is($keyvals{oops},22);
is($keyvals{oopsy},22);
is(ref($keyvals{range}),"ARRAY");
eq_array($keyvals{range},[qw/a b/],"Compare quoted array");
eq_array($keyvals{curly},[qw/c d/],"Compare curly bracketed array");
eq_array($keyvals{unquot},[qw/1 2/], "Compare unquoted internal array");
eq_array($keyvals{wow},[qw/c d e/], "Compare final non-quoted array");


print "# parse_obslist\n";

my @expected = (5,9,10,11);
my @obs = parse_obslist("5,9:11");

is(scalar(@obs), scalar(@expected));

for (0..scalar(@expected)) {
  is($obs[$_], $expected[$_]);
}


exit;

sub eq_array {
  my ($a, $b, $c) = @_;

  if (defined $c) {
    $c .= ":";
  } else {
    $c = '';
  }

  is(scalar(@$a), scalar(@$b), "$c Compare size");

  for my $i (0..$#$a) {
    is($a->[$i], $b->[$i], "$c Compare element $i");
  }

}
