#!/bin/perl
#
# Generate SUN/236 from a template and howto files
#                 Hacked by PH from original by   (frossie@jach.hawaii.edu)
#------------------------------------------------------------------------

use strict;
use File::Copy;

my $master = "sun236_template.tex";
my $sun = "sun236.tex";

$ENV{ORAC_INSTRUMENT} = "CGS4";

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
      copy ($ENV{ORAC_DIR}."/primitives/spectroscopy/".$doc,"$doc$pod");

    } elsif ($key=~/BIN/) {

      copy ($ENV{ORAC_DIR}."/bin/".$doc,"$doc$pod");

    } elsif ($key=~/RECIPE/) {

      copy ($ENV{ORAC_DIR}."/recipes/".$ENV{ORAC_INSTRUMENT}."/".$doc,"$doc$pod");
      copy ($ENV{ORAC_DIR}."/recipes/spectroscopy/".$doc,"$doc$pod");

    } else {

      print "broken key\n";

    }

    # We need V0.54 of Pod::LaTeX for these options
    # Note that Pod::Select will not allow two negative
    # selections. Until we fix that we have to be inclusive
    # rather than exclusive
    # (note that we could use Pod::LaTeX directly).
    system("/local/perl-5.6/bin/pod2latex --sections 'NAME|DESCRIPTION|NOTE' --modify --h1level 4 $doc$pod")
      && die "Error running pod2latex: $!";

    open (LATEX,"$doc.tex")
      or die "Could not open $doc.tex";

    # Do some post processing
    my @lines = <LATEX>;

    for my $line (@lines ) {
      # We dont really want the DESCRIPTION heading
      if ($line =~ /DESCRIPTION/) {
	$line  = "\n" .'\mbox{}'."\n";
      }


    }


    print SUN @lines;

    print "Done $doc\n";

    unlink "$doc$pod";
    unlink "$doc.tex";

  }

}

