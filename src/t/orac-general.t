
# Test ORAC::General

use strict;
use warnings;
use Test;

BEGIN { plan tests => 20 };

use ORAC::General qw/ max min log10 nint utdate
  parse_keyvalues parse_obslist /;


# First test max and min

my @testing = ( -20, 52, 0, 1, 1);

print "# Min/Max\n";

ok(max(@testing), 52);
ok(min(@testing), -20);
ok(min(0,1,2), 0);
ok(max(-20,-10,0), 0);

print "# NINT\n";

ok(nint(5.5), 6);
ok(nint(5.9), 6);
ok(nint(5), 5);
ok(nint(5.49),5);


print "# log10\n";

ok(log10(100), 2);
ok(log10(0.1), -1);


print "# utdate\n";

# We basically have to reimplement the utdate function!!!!!
# This is actually shorter than utdate()!
my @time = gmtime();
$time[5] += 1900;
$time[4]++;
my $now = sprintf("%04d%02d%02d", $time[5], $time[4], $time[3]);

ok(utdate(), $now);


print "# parse_keyvalues\n";

my %keyvals = parse_keyvalues("X=22,Y=hello,Z=[-22]");

ok($keyvals{x}, 22);
ok($keyvals{y}, "hello");
ok($keyvals{z}, "[-22]");

print "# parse_obslist\n";

my @expected = (5,9,10,11);
my @obs = parse_obslist("5,9:11");

ok(scalar(@obs), scalar(@expected));

for (0..scalar(@expected)) {
  ok($obs[$_], $expected[$_]);
}
