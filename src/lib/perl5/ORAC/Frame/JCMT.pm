package ORAC::Frame::JCMT;

# A package to describe a JCMT frame object for the
# ORAC pipeline

use 5.004;
use ORAC::Frame;

# Let the object know that it is derived from ORAC::Frame;
@ORAC::Frame::JCMT::ISA = qw/ORAC::Frame/;


# standard error module and turn on strict
use Carp;
use strict;



# Supply a new method for finding a group

sub findgroup {

  my $self = shift;

  return "JCMT";

}





1;
