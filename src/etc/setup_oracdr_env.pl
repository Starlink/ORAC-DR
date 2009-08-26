#!perl

use strict;
use File::Spec;

# Check environment variables.
if( ! defined( $ENV{'ORAC_DIR'} ) ) {
  die "ORAC_DIR environment variable not set!";
}
if( ! defined( $ENV{'ORAC_CAL_ROOT'} ) ) {
  $ENV{'ORAC_CAL_ROOT'} = File::Spec->catfile( $ENV{'ORAC_DIR'}, File::Spec->updir, "cal" );
}
if( ! defined( $ENV{'ORAC_PERL5LIB'} ) ) {
  $ENV{'ORAC_PERL5LIB'} = File::Spec->catfile( $ENV{'ORAC_DIR'}, "lib", "perl5" );
}

# Handle arguments.
my $shell = uc( $ARGV[0] );
my $ut = $ARGV[1];

if( ! defined( $shell ) ) {
  $shell = "csh";
}
if( ! defined( $ut ) ) {
  $ut = `date -u +\%Y\%m\%d`;
}

# Environment variable hash.
my %envs = ( 'ACSIS' => { ORAC_DATA_CAL => File::Spec->catfile( $ENV{'ORAC_CAL_ROOT'}, "acsis" ),
                          ORAC_DATA_ROOT => "/jcmtdata",
                          ORAC_DATA_IN => File::Spec->catfile( "/jcmtdata", "raw", "acsis", "spectra", $ut ),
                          ORAC_DATA_OUT => File::Spec->catfile( "/jcmtdata", "reduced", "acsis", "spectra", $ut ),
                          ORAC_LOOP => 'flag',
                          ORAC_PERSON => 'bradc',
                          ORAC_SUN => 'xxx',
                        },
             'CGS4'  => { ORAC_DATA_CAL => File::Sepc->catfile( $ENV{'ORAC_CAL_ROOT'}, "cgs4" ),
                          ORAC_DATA_ROOT => "/ukirtdata",
                          ORAC_DATA_IN => File::Spec->catfile( "/ukirtdata", "raw", "cgs4", $ut ),
                          ORAC_DATA_OUT => File::Spec->catfile( "/ukirtdata", "reduced", "cgs4", $ut ),
                          ORAC_PERSON => 'bradc',
                          ORAC_LOOP => 'flag',
                          ORAC_SUN => '230',
                        },
             'WFCAM' => { ORAC_DATA_CAL => File::Spec->catfile( $ENV{'ORAC_CAL_ROOT'}, "wfcam" ),
                          ORAC_DATA_ROOT => "/ukirtdata",
                          ORAC_DATA_IN => File::Spec->catfile( "/ukirtdata", "raw", lc( $ENV{'ORAC_INSTRUMENT'} ), $ut ),
                          ORAC_DATA_OUT => File::Spec->catfile( "/ukirtdata", "reduced", lc( $ENV{'ORAC_INSTRUMENT'} ), $ut ),
                          ORAC_PERSON => 'bradc',
                          ORAC_LOOP => 'flag',
                          ORAC_SUN => '',
                          HDS_MAP => 0,
                        },
           );

# List of instrument-agnostic variables to send back.
my @orac_envs = qw/ ORAC_CAL_ROOT ORAC_PERL5LIB /;

my $inst = uc( $ENV{'ORAC_INSTRUMENT'} );

# Special-case for WFCAM.
if( $inst =~ /^WFCAM/ ) {
  $inst = "WFCAM";
}

# Print out the environment variable settings.
foreach my $env ( keys %{$envs{$inst}} ) {
  my $value = $envs{$inst}->{$env};
  if( $shell eq 'CSH' ) {
    print "setenv $env '$value' ; ";
  } elsif( $shell eq 'BASH' ) {
    print "export $env='$value' ; ";
  }
}

# ...and the instrument-agnostic ones too.
foreach my $oracenv ( @orac_envs ) {
  if( $shell eq 'CSH' ) {
    print "setenv $oracenv '$ENV{$oracenv}' ; ";
  } elsif( $shell eq 'BASH' ) {
    print "export $oracenv='$ENV{$oracenv}' ; ";
  }
}

