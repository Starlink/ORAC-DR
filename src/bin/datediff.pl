#!/usr/bin/perl

# S T A R L I N K  D O C U M E N T I O N ------------------------------------

#+
#  Name:
#    datediff

#  Purposes:
#    Determines the difference of two dates in days.

#  Language:
#    Perl script

#  Invocation:
#    Invoked by source ${ORAC_DIR}/bin/datediff.pl

#  Usage
#    datediff --date1 <first_date> --date2 <second_date>

#  Description:
#    This calculates the difference of two dates in days,
#    the dates being in yyyymmdd format.  It finds the
#    difference date2 - date1.

#  Arguments:
#    --date1
#       The first date in yyyymmdd format.
#    --date2
#       The second date in yyyymmdd format.

#  Authors:
#    MJC: Malcolm J. Currie (Starlink)

#  Revision:
#    $Id$

#  Copyright:
#    Copyright (C) 2004 Particle Physics and Astronomy Research
#    Council. All Rights Reserved.

#-

use strict;
use vars qw/$VERSION/;


# Load Modules
# ============
use Pod::Usage;
use Getopt::Long;
use Time::Local;

# Command-line options handling.
# ==============================
my ( $before, $after );
GetOptions( "date1:s" => \$before,
            "date2:s" => \$after );

# Validate that two dates were supplied.
unless ( defined( $before ) && defined( $after ) ) { 
   die "Two dates should be supplied on the command line using " .
       "--date1 and --date2 options.\n";
}

# Break the date string into components.
# ======================================

# The before date.  The months count from zero and the years from 1900!
my ( $day1, $month1, $year1 );
$day1 = substr( $before, 6, 2 );
$month1 = substr( $before, 4, 2 ) - 1;
$year1 = substr( $before, 0, 4 ) - 1900;

# The after date.
my ( $day2, $month2, $year2 );
$day2 = substr( $after, 6, 2 );
$month2 = substr( $after, 4, 2 ) - 1;
$year2 = substr( $after, 0, 4 ) - 1900;

my $strb = timelocal( 0, 0, 0, $day1, $month1, $year1 );
my $stra = timelocal( 0, 0, 0, $day2, $month2, $year2 );

my $diff =int( ( $stra - $strb ) / 86400 );
print "$diff days\n";

# $Log$
# Revision 1.1  2005/03/25 22:10:40  mjc
# Original version of 2004 Oct 6.
#
#

# Podule
# ======

=head1 NAME

datediff -- Determines the difference of two dates in days.

=head1 SYNOPSIS

   datediff --before --date2

=head1 DESCRIPTION

C<datediff> calculates the difference of two dates in days,
the dates being in I<yyyyddmm> format.  It finds the
difference date2 - before.

=head1 OPTIONS

=over 4

=item --date1

The first date in I<yyyymmdd> format.

=item --date2

The second date in I<yyyymmdd> format.

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie <mjc@star.rl.ac.uk>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research Council.
All Rights Reserved.

=cut
