package ORAC::Version;

=head1 NAME

ORAC::Version - Obtain ORAC-DR version number and associated information

=head1 SYNOPSIS

  use ORAC::Version;
  $VERSION = ORAC::Version->getVersion();

  ORAC::Version->setApp( "ORAC-DR" );
  $appname = ORAC::Version->getApp();

=head1 DESCRIPTION

This module is used to determine the version number suitable for
the complete data reduction pipeline, including recipes.

It can also be used to set global application properties such as
the name of the application.

=cut

use warnings;
use strict;
use Carp;

use File::Spec;

use Starlink::Versions;

use vars qw/ $VERSION /;
$VERSION = '1.01';

=head1 CLASS METHODS

=over 4

=item B<getVersion>

Returns a simple string representation of the ORAC-DR global version
number. This should be sufficient to locate the specific repository
revision associated with the release. For git repositories it will
be the short form of the SHA1 commit id.

 $version = ORAC::Version->getVersion();

Note that if the source tree has been locally modified this will not
necessarily be reflected in the version string.

If the version can not be determined a string "unknown" will be returned.

The value is cached (and assumes that once calculated it will not
change during runtime).

=cut

{
my $CACHE_VER;
sub getVersion {
  my $class = shift;
  return $CACHE_VER if defined $CACHE_VER;
  my ( $branch, $version, $date ) = oracversion_global();

  if( ! defined( $version ) ) {
    $version = "unknown";
  }

  if( defined( $version ) ) {
    chomp($version);
    $version = substr( $version, 0, 12 );
  }

  $CACHE_VER = $version;
  return $version;
}
}

=item B<oracversion_global>

Returns the global ORAC-DR version for the system.

In list context returns the string representation, the commit ID
and the date of that commit.

 ($string, $commit, $commitdate) = ORAC:::Version->oracversion_global();

In scalar context returns just the string representation:

  $string = starversion_global();

=cut

sub oracversion_global {
  my %version = _oracversion() or return();
  if( wantarray ) {
    return ( $version{'STRING'}, $version{'COMMIT'}, $version{'COMMITDATE'} );
  } else {
    return $version{'STRING'};
  }
}

=item B<setApp>

Sets the global application name. Defaults to "ORAC-DR".

  ORAC::Version->setApp( "App" );

=item B<getApp>

Returns the global application name.

  $app = ORAC::Version->getApp();

=cut

{
my $APP = "ORAC-DR";
sub setApp {
  my $class = shift;
  $APP = shift;
}
sub getApp {
  return $APP;
}
}

=back

=begin __PRIVATE__

=head1 PRIVATE FUNCTIONS

=over 4

=item B<_oracversion>

Attempts to find out the global version information. Returns a hash with keys

 STRING - String form of commit including branch as well as commit id and date
 COMMIT - Commit identifier
 COMMITDATE - Date of that commit

This information is obtained through a number of methods:

 1. Locating $GIT_DIR in the checkout tree and running $ORAC_DIR/version.sh

 2. Locating a file $ORAC_DIR/oracdr.version containing the output from version.sh

So the presence of a git repository is always preferable to a hard-wired version file.

Is cached, since the version number will not change during pipeline execution (or at least it shouldn't).

=cut

  {
    my %CACHE_VERSION;
    sub _oracversion {
      if( ! defined( $CACHE_VERSION{'NOTFOUND'} ) &&
          ! $CACHE_VERSION{'NOTFOUND'} &&
          ! defined( $CACHE_VERSION{'STRING'} ) ) {
        my $script = File::Spec->catfile( $ENV{'ORAC_DIR'}, "version.sh" );
        my $info;
        if( -e $script ) {
          local $ENV{'GIT_DIR'} = File::Spec->catdir( $ENV{'ORAC_DIR'}, File::Spec->updir, ".git" );
          if( open my $proch, "sh $script 2>/dev/null |" ) {
            my @output = <$proch>;
            close $proch;
            if( @output ) {
              chomp @output;
              $info = Starlink::Versions::_get_git_version( Data => \@output );
            }
	    # it is possible that git is installed but it is a version that
	    # can not read the pack files. eg CADC has 1.5.0.2 which won't
	    # read the commit log/date from a 1.6 repository.
	    if (!exists $info->{COMMITDATE}) {
	      $info = undef;
	    }
          }
        }
        if( ! defined( $info ) ) {
          my $file = File::Spec->catfile( $ENV{'ORAC_DIR'}, "oracdr.version" );
          $info = Starlink::Versions::_get_git_version( File => $file );
        }
        if( defined( $info ) ) {
          %CACHE_VERSION = %$info;
        } else {
          $CACHE_VERSION{'NOTFOUND'} = 1;
        }
      }
      return %CACHE_VERSION;
    }
  }


=back

=end __PRIVATE__

=head1 SEE ALSO

L<Starlink::Versions>

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2009 Science and Technology Facilities Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
