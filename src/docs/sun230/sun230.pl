#!/bin/perl
#
#
#                                                    (frossie@jach.hawaii.edu)
#------------------------------------------------------------------------

use File::Copy;

$master = "sun230_master.tex";
$sun = "sun230.tex";

# CHANGE TO YOUR SUN DOCUMENT HERE
open(MASTER, "<$master");
open(SUN,">$sun");

unless (defined $ENV{ORAC_DIR}) {die "Set your ORAC_DIR!\n"};
unless (defined $ENV{ORAC_INSTRUMENT}) {die "Set your ORAC_INSTRUMENT!\n"};

print "Generating $sun from $master\n";
print "Using pods for $ENV{ORAC_INSTRUMENT} in $ENV{ORAC_DIR} \n";



foreach $line (<MASTER>) {

  print SUN $line;

  if ($line=~/ORACDRDOC/) {

    ($key,$doc) = split (':',$line,2);
    chomp($doc);
    
    if ($key =~/HOWTO/) {

      copy ($ENV{ORAC_DIR}."/howto/".$doc,$doc);

    } elsif ($key=~/PRIMITIVE/) {

      copy ($ENV{ORAC_DIR}."/primitives/".$ENV{ORAC_INSTRUMENT}."/".$doc,$doc);

    } elsif ($key=~/BIN/) {

      copy ($ENV{ORAC_DIR}."/bin/".$doc,$doc);

    } elsif ($key=~/RECIPE/) {

      copy ($ENV{ORAC_DIR}."/recipes/".$ENV{ORAC_INSTRUMENT}."/".$doc,$doc);

    }

    system("pod2latex $doc");
    open (LATEX,"$doc.tex");

    print SUN <LATEX>;

    print "Done $doc\n";

  }

}

