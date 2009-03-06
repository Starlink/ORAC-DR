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
$VERSION = sprintf("%d", q$Revision: 7007 $ =~ /(\d+)/);

=head1 CLASS METHODS

=over 4

=item B<getVersion>

Uses the $ORAC_DIR environment variable and the svnversion command
to determine the site-wide version number string.

 $version = ORAC::Version->getVersion();

If a file called C<.version> is present in $ORAC_DIR it is assumed
to contain the global version number. If not present the svnversion
command will be run to determine the state of the source code checkout
tree. If $ORAC_DIR refers to an exported tree then the version will
be "UNKNOWN".

Note that if the source code tree has been locally modified the
version string will not be a single number.

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

  chomp($version) if defined $version;
  $CACHE_VER = $version;
  return $version;
}
}

sub oracversion_global {
  my %version = oracversion() or return();
  if( wantarray ) {
    return ( $version{'STRING'}, $version{'COMMIT'}, $version{'COMMITDATE'} );
  } else {
    return $version{'STRING'};
  }
}

  {
    my %CACHE_VERSION;
    sub oracversion {
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

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.
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
