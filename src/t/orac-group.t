# Test ORAC::Group

# This test requires access to ORAC_DATA_CAL

use strict;
use warnings;
use Test;

BEGIN {
  unless (exists $ENV{ORAC_DATA_CAL}) {
    print "1..0 # Skip ORAC_DATA_CAL env var not set\n";
    exit;
  }
}

BEGIN { plan tests => 10};

use ORAC::Group;

# Create some frames

my $frm1 = new MY::Frame;
my $frm2 = new MY::Frame;
my $frm3 = new MY::Frame;
my $frm4 = new MY::Frame;
my $frm5 = new MY::Frame;

# Some headers for the frames
$frm1->hdr('mode', 'DARK');
$frm2->hdr('mode', 'SKY');
$frm3->hdr('mode', 'OBJECT');
$frm4->hdr('mode', 'OBJECT');
$frm5->hdr('mode', 'SKY');

$frm1->hdr('instrume', 'IRCAM');
$frm2->hdr('instrume', 'IRCAM');
$frm3->hdr('instrume', 'CGS4');
$frm4->hdr('instrume', 'CGS4');
$frm5->hdr('instrume', 'CGS4');

$frm1->uhdr('nod', 'off');
$frm2->uhdr('nod', 'on');
$frm3->uhdr('nod', 'off');
$frm4->uhdr('nod', 'on');
$frm5->uhdr('nod', 'off');

# Create a group
my $grp = new ORAC::Group("name");

# Put something into it

$grp->push($frm1, $frm2, $frm3, $frm4, $frm5);

ok($grp->num, 4);

# Check sub grouping

my $subgrp = $grp->subgrp('instrume' => 'CGS4');

# Now check membership
ok($subgrp->num, 2);
ok($subgrp->members->[0],$frm3);
ok($subgrp->members->[1],$frm4);
ok($subgrp->members->[2],$frm5);

my @subs = $grp->subgrps('mode');
ok(scalar(@subs), 3);

# Should be 4 separate groups
@subs = $grp->subgrps('instrume', 'nod');

ok(scalar(@subs), 4);

# ...but we can't gurantee the order...



@subs = $grp->subgrps('nod');
ok(scalar(@subs), 2);


@subs = $grp->subgrps('mode');
ok(scalar(@subs), 3);

@subs = $grp->subgrps('modeds');
ok(scalar(@subs), 1);















# Define our own frames to be stored in the Group since we dont
# want to bother with real ORAC::Frame objects

package MY::Frame;


sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $frame = {
	       Header => {},
	       UHeader => {},
	      };
  bless($frame, $class);
}


sub hdr {
  my $self = shift;
  if (@_) {
    if (scalar(@_) == 1) {
      my $key = shift;
      return $self->{Header}->{$key};
    } else {
      %{ $self->{Header} } = ( %{ $self->{Header} }, @_ );
    }
  } else {
    return $self->{Header};
  }
}

sub uhdr {
  my $self = shift;
  if (@_) {
    if (scalar(@_) == 1) {
      my $key = shift;
      return $self->{UHeader}->{$key};
    } else {
      %{ $self->{UHeader} } = ( %{ $self->{UHeader} }, @_ );
    }
  } else {
    return $self->{UHeader};
  }
}

sub isgood {
  my $self = shift;
  if (@_) { $self->{IsGood} = shift;  }
  $self->{IsGood} = 1 unless defined $self->{IsGood};
  return $self->{IsGood};
}

sub number {
  1;
}
