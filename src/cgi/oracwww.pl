#!/usr/local/bin/perl -w

# This is so that warnings appear on the screen
BEGIN {
  use CGI::Carp qw/carpout/;
  carpout(\*STDOUT);
}

use lib "/WWW/JACpublic/UKIRT/software/cgi-bin/lib";

# Load relevant modules
#use Pod::Simple::HTML;
use Pod::Find qw/ pod_where /;
use Pod::ORACHtml;
use CGI;
use CGI::Carp qw/ fatalsToBrowser /;
use File::Spec;

use strict;

$| = 1;

my $base_dir = "/ukirt_sw/oracdr";

# Set up list of valid instruments to check CGI input against.
my %valid_instruments = (
                         "ACSIS" => 1,
                         "CGS4" => 1,
                         "CLASSICCAM" => 1,
                         "GMOS" => 1,
                         "INGRID" => 1,
                         "IRCAM" => 1,
                         "IRIS2" => 1,
                         "ISAAC" => 1,
                         "MICHELLE" => 1,
                         "NACO" => 1,
                         "NIRI" => 1,
                         "SCUBA" => 1,
                         "SOFI" => 1,
                         "UFTI" => 1,
                         "UIST" => 1,
                         "WFCAM" => 1,
                        );

# Set up list of valid modes to check CGI input against.
my %valid_modes = (
                   "imaging" => 1,
                   "spectroscopy" => 1,
                   "ifu" => 1,
                   "general" => 1,
                  );

# Set up the page.
my $query = new CGI;
my $qv = $query->Vars;

if( defined( $qv->{'keywords'} ) ) {
  $qv->{'pod'} = $qv->{'keywords'};
}

foreach my $key (keys %$qv) {
  if( $qv->{$key} eq '' ) {
    $qv->{'pod'} = $key;
    last;
  }
}

print $query->header;

# Verify input arguments.
my $instrument = "";
if( defined( $qv->{'inst'} ) ) {

  # Set this to a temporary variable and untaint.
  my $inst = $qv->{'inst'};
  $inst =~ s/[^A-Za-z0-9]//g;
  $inst =~ /(.*)/;
  $inst = $1;

  if( $valid_instruments{ $inst } ) {
    $instrument = $inst;
  }
}

my $mode = "";
if( defined( $qv->{'mode'} ) ) {

  # Set this to a temporary variable and untaint.
  my $temp_mode = $qv->{'mode'};
  $temp_mode =~ s/[^A-Za-z0-9]//g;
  $temp_mode =~ /(.*)/;
  $temp_mode = $1;

  if( $valid_modes{ $temp_mode } ) {
    $mode = $temp_mode;
  }
}

my $pod = "";
if( defined( $qv->{'pod'} ) ) {
  my $temp_pod = $qv->{'pod'};

  # Strip out anything that isn't a letter, a number, or an underscore.
  $temp_pod =~ s/[^a-zA-Z0-9_]//;

  # Untaint.
  $temp_pod =~ /(.*)/;
  $pod = $1;
}

my $imaging_root = "imaging";
my $spec_root = "spectroscopy";
my $ifu_root = "ifu";
my $het_root = "heterodyne";
my $scuba_root = "SCUBA";

my @searchdirs;

if( $instrument ne '' ) {

  push @searchdirs, "$base_dir/primitives/$instrument";
  push @searchdirs, "$base_dir/recipes/$instrument";

  if( $mode ne '' ) {

    push @searchdirs, "$base_dir/primitives/$mode/$instrument";
    push @searchdirs, "$base_dir/recipes/$mode/$instrument";
    push @searchdirs, "$base_dir/primitives/$mode";
    push @searchdirs, "$base_dir/recipes/$mode";

  } else {

    push @searchdirs, "$base_dir/primitives/$imaging_root";
    push @searchdirs, "$base_dir/recipes/$imaging_root";
    push @searchdirs, "$base_dir/primitives/$spec_root";
    push @searchdirs, "$base_dir/recipes/$spec_root";
    push @searchdirs, "$base_dir/primitives/$ifu_root";
    push @searchdirs, "$base_dir/recipes/$ifu_root";
    push @searchdirs, "$base_dir/primitives/$het_root";
    push @searchdirs, "$base_dir/recipes/$het_root";
    push @searchdirs, "$base_dir/primitives/$scuba_root";
    push @searchdirs, "$base_dir/recipes/$scuba_root";
  }

} elsif( $mode ne '' ) {

  push @searchdirs, "$base_dir/primitives/$mode";
  push @searchdirs, "$base_dir/recipes/$mode";

} else {

  push @searchdirs, "$base_dir/lib/perl5";
  push @searchdirs, "$base_dir/howto";
  push @searchdirs, "$base_dir/bin";
  push @searchdirs, "$base_dir/primitives/$imaging_root";
  push @searchdirs, "$base_dir/recipes/$imaging_root";
  push @searchdirs, "$base_dir/primitives/$spec_root";
  push @searchdirs, "$base_dir/recipes/$spec_root";
  push @searchdirs, "$base_dir/primitives/$ifu_root";
  push @searchdirs, "$base_dir/recipes/$ifu_root";
  push @searchdirs, "$base_dir/primitives/$het_root";
  push @searchdirs, "$base_dir/recipes/$het_root";
  push @searchdirs, "$base_dir/primitives/$scuba_root";
  push @searchdirs, "$base_dir/recipes/$scuba_root";
}

# Find the appropriate POD.
my $found = pod_where( { -verbose => 0,
                         -inc => 0,
                         -dirs => \@searchdirs,
                       }, $pod );

if( defined( $found ) ) {

  # Parse the POD.
  my $parser = new Pod::ORACHtml( );
  $parser->parse_from_file( $found );

} else {

  print $query->start_html( -title => 'POD not found' );
  print $query->h1("POD not found");
  print "POD for <tt>$pod</tt> could not be found.<br>\n";
  print "Search path was:<br><ul>\n";
  foreach my $dir ( @searchdirs ) {
    print "<li>$dir</li>\n";
  }
  print "</ul>";
  print $query->end_html;

}
