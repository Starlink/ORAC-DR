#!/bin/perl
#
# Generate SUN/230 from a template and howto files
#                                                    (frossie@jach.hawaii.edu)
#------------------------------------------------------------------------

use strict;
use File::Copy;

my $master = "sun230_master.tex";
my $sun = "sun230.tex";

unless (defined $ENV{ORAC_DIR}) {die "Set your ORAC_DIR!\n"};
unless (defined $ENV{ORAC_INSTRUMENT}) {die "Set your ORAC_INSTRUMENT!\n"};

# CHANGE TO YOUR SUN DOCUMENT HERE
open(MASTER, "<$master")
  or die "Unable to open $master for read: $!";
open(SUN,">$sun")
  or die "Unable to open $sun for write: $!";

print "Generating $sun from $master\n";
print "Using pods for $ENV{ORAC_INSTRUMENT} in $ENV{ORAC_DIR} \n";

my $pod = ".pod";

foreach my $line (<MASTER>) {

  print SUN $line;

  if ($line=~/ORACDRDOC/) {

    my ($key,$doc) = split (':',$line,2);
    chomp($doc);
    
    if ($key =~/HOWTO/) {

      copy ($ENV{ORAC_DIR}."/howto/".$doc,"$doc$pod");

    } elsif ($key=~/PRIMITIVE/) {

      copy ($ENV{ORAC_DIR}."/primitives/".$ENV{ORAC_INSTRUMENT}."/".$doc,"$doc$pod");

    } elsif ($key=~/BIN/) {

      copy ($ENV{ORAC_DIR}."/bin/".$doc,"$doc$pod");

    } elsif ($key=~/RECIPE/) {

      copy ($ENV{ORAC_DIR}."/recipes/".$ENV{ORAC_INSTRUMENT}."/".$doc,"$doc$pod");

    }

    system("pod2latex --modify $doc$pod")	&& die "Error running pod2latex: $!";
    open (LATEX,"$doc.tex");

    print SUN <LATEX>;

    print "Done $doc\n";

    unlink "$doc$pod";
    unlink "$doc.tex";

  }

}

