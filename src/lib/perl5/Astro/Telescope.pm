package Astro::Telescope;

=head1 NAME

Astro::Telescope - class for obtaining telescope information

=head1 SYNOPSIS

  use Astro::Telescope;

  $tel = new Astro::Telescope( 'UKIRT' );

  $latitude = $tel->lat;
  $longitude = $tel->long;
  $altitude = $tel->alt;

  %limits = $tel->limits;

  @telescopes = Astro::Telescope->telNames();

=head1 DESCRIPTION

A class for handling properties of individual telescopes such
as longitude, latitude, height and observational limits.

=cut

use 5.006;
use warnings;
use strict;
use Astro::SLA qw/slaObs/;

use vars qw/ $VERSION /;
$VERSION = '0.50';


# separator to use for output sexagesimal notation
our $Separator = " ";


=head1 METHODS

=head2 Constructor

=over

=item B<new>

Create a new telescope object. Takes the telescope abbreviation
as the single argument.

  $tel = new Astro::Telescope( 'VLA' );

An argument must be supplied. Returns C<undef> if the telescope
is not recognized.

If more than one argument is supplied the assumption
is that the user is supplying telescope details. In that
case a minimum of "Name", "Long" and "Lat" must be supplied

  $tel = new Astro::Telescope('telescope');
  $tel = new Astro::Telescope(Name => 'JCMT', Long => $long, Lat => $lat );


=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  return undef unless @_;

  # Create the new object
  my $tel = bless {}, $class;

  # Configure it with the supplied telescope name
  # or other arguments
  $tel->_configure( @_ ) or return undef;

  return $tel;
}

=back

=head2 Acessor Methods

=over 4

=item B<name>

Returns the abbreviated name of the telescope. This is the same as
that given to the constructor (although it will be upper-cased).

The object can be reconfigured to a new telescope by supplying
a new abbreviation to this method.

  $tel->name('JCMT');

The object will not change state if the name is not known.

=cut

sub name {
  my $self = shift;
  if (@_) {
    my $name = shift;
    $self->_configure( $name );
  }
  return $self->{Name};
}

=item B<fullname>

Returns the full name of the telescope. For example, if the abbreviated
name is "JCMT" this will return "JCMT 15 metre".

=cut

sub fullname {
  my $self = shift;
  return $self->{FullName};
}

=item B<long>

Longitude of the telescope (east +ve). By default this is in radians.

An argument of "d" or "s" can be supplied to retrieve the value
in decimal degrees or sexagesimal string format respectively.

 $string = $tel->long("s");

=cut

sub long {
  my $self = shift;
  my $long = $self->{Long};
  $long = $self->_cvt_fromrad( $long, shift ) if @_;
  return $long
}

=item B<lat>

Geodetic latitude of the telescope. By default this is in radians.

An argument of "d" or "s" can be supplied to retrieve the value
in decimal degrees or sexagesimal string format respectively.

  $deg = $tel->lat("d");

=cut

sub lat {
  my $self = shift;
  my $lat = $self->{Lat};
  $lat = $self->_cvt_fromrad( $lat, shift ) if @_;
  return $lat
}

=item B<alt>

Altitude of the telescope in metres.

=cut

sub alt {
  my $self = shift;
  return $self->{Alt};
}

=item B<limits>

Return the telescope limits.

  %limits = $tel->limits;

The limits are returned as a hash with the following keys:

=over 4

=item type

Specifies the way in which the limits are specified. Effectively the
telescope mount. Values of "AZEL" (for altaz telescopes) and "HADEC"
(for equatorial telescopes) are currently supported.

=item el

Elevation limit of the telescope. Value is a hash with keys C<max>
and C<min>. Units are in radians. Only used if C<type> is C<AZEL>.

=item ha

Hour angle limit of the telescope. Value is a hash with keys C<max>
and C<min>. Units are in radians. Only used if C<type> is C<HADEC>.

=item dec

Declination limit of the telescope. Value is a hash with keys C<max>
and C<min>. Units are in radians. Only used if C<type> is C<HADEC>.

=back

Only some telescopes have limits defined (please send patches with new
limits if you know them). If limits are not available for this
telescope an empty list is returned.

=cut

sub limits {
  my $self = shift;

  # Just put them all in a big hash (this could come outside
  # the method since it does not change)
  my %limits = (
		JCMT => {
			 type => "AZEL",
			 el => { # 5 to 88 deg
				max => 88 * Astro::SLA::DD2R,
				min => 5 * Astro::SLA::DD2R,
			       },
			},
		UKIRT => {
			  type => "HADEC",
			  ha => { # +/- 4.5 hours
				max => 4.5 * Astro::SLA::DH2R,
				min => -4.5 * Astro::SLA::DH2R,
				},
			  dec=> { # -42 to +60 deg
				max => 60 * Astro::SLA::DD2R,
				min => -42 * Astro::SLA::DD2R,
				},
			 },

	       );

  # Return the hash if it exists
  if (exists $limits{ $self->name }) {
    return %{ $limits{ $self->name } };
  } else {
    return ();
  }

}

=back

=head2 Class Methods

=over 4

=item B<telNames>

Obtain a sorted list of all supported telescope names.

  @names = Astro::Telescope->telNames;

=cut

sub telNames {
  my $i = 1;
  my $name2 = ''; # needed for slaObs XS
  my @names;
  while ($name2 ne '?') {
    my ($name,$w, $p, $h);
    slaObs($i, $name, $name2, $w, $p, $h);
    push(@names, $name) unless $name2 eq '?';
    $i++;
  }
  return sort @names;
}

=back

=begin __PRIVATE__

=head2 Private Methods

=over 4

=item B<_configure>

Reconfigure the object for a new telescope. Called automatically
by the constructor or if a new telescope name is provided.

Returns C<undef> if the telescope was not supported.

If more than one argument is supplied the assumption
is that the user is supplying telescope details. In that
case a minimum of "Name", "Long" and "Lat" must be supplied
else the routine returns undef.

  $t->_configure('telescope');
  $t->_configure(Name => 'JCMT', Long => $long, Lat => $lat );

=cut

sub _configure {
  my $self = shift;
  if (scalar(@_) == 1) {
    my $name = uc(shift);
    slaObs(0, $name, my $fullname, my $w, my $p, my $h);
    return undef if $fullname eq '?';

    # Correct for East positive
    $w *= -1;

    $self->{Name} = $name;
    $self->{FullName} = $fullname;
    $self->{Long} = $w;
    $self->{Lat} = $p;
    $self->{Alt} = $h;

    return 1;
  } else {
    my %args = @_;
    return undef unless exists $args{Name} && exists $args{Long}
      && exists $args{Lat};

    for my $key (qw/ Name Long Lat Alt FullName / ) {
      $self->{$key} = $args{$key} if exists $args{$key};
    }
    return 1;
  }
}

=item B<_cvt_fromrad>

Convert radians to either degrees ("d") or sexagesimal string ("s").

  $converted = $self->_cvt_fromrad($rad, "s");

If the second argument is not supplied the string is returned
unmodified.

The string is space separated by default but this can be overridden
by setting the variable $Astro::Telescope::Separator to a new value.

=cut

sub _cvt_fromrad {
  my $self = shift;
  my $rad = shift;
  my $format = shift;
  return $rad unless defined $format;

  my $out;
  if ($format =~ /^d/) {
    $out = $rad * Astro::SLA::DR2D;
  } elsif ($format =~ /^s/) {

    my @dmsf;
    Astro::SLA::slaDr2af(2, $rad, my $sign, @dmsf);
    $sign = '' if $sign eq "+";
    $out = $sign . join($Separator,@dmsf[0..2]) . ".$dmsf[3]";
  }

}

=back

=head2 Backwards Compatibility

These methods are provided for programs that used the original
interface:

  lat_by_rad, long_by_rad, lat_by_deg, long_by_deg, alt_by_deg,
  alt_by_rad

=cut

sub lat_by_rad {
  my $self = shift;
  return $self->lat;
}

sub long_by_rad {
  my $self = shift;
  return $self->long;
}

sub alt_by_rad {
  my $self = shift;
  return $self->alt;
}

sub lat_by_deg {
  my $self = shift;
  return $self->lat('d');
}

sub long_by_deg {
  my $self = shift;
  return $self->long('d');
}

sub alt_by_deg {
  my $self = shift;
  return $self->alt('d');
}

=end __PRIVATE__

=head1 REQUIREMENTS

The list of telescope properties is currently obtained from
those provided by SLALIB (C<Astro::SLA>).

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research Council.
All Rights Reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;

