package ORAC::BaseFile;

=head1 NAME

ORAC::BaseFile - Shared Base class for Frame and Group classes

=head1 SYNOPSIS

  use base qw/ ORAC::BaseFile /;


=head1 DESCRIPTION

This class contains methods that are shared by both Frame and Group
classes. For example, header and user-header manipulation.

=cut

use 5.006;
use Carp;
use strict;
use warnings;
use vars qw/ $VERSION /;

use Astro::FITS::Header;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 PUBLIC METHODS

The following methods are available in this class:

=head2 Accessor Methods

=over 4

=item B<fits>

Return (or set) the C<Astro::FITS::Header> object associated with
the FITS header from the raw data. If you simply want to access
individual FITS headers then you probably should be using
the C<hdr> method.

  $Frm->fits( $fitshdr );
  $fitshdr = $Frm->fits;

Translated FITS headers are available using the C<uhdr> method.

If no FITS header has been associated with this object, one
is automatically created from the C<hdr>. This allows the
header to be derived from either a FITS object or a normal
hash.

=cut

sub fits {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    # Test its type unless it is undef
    if (defined $arg) {
      croak "Argument to fits() must be of class Astro::FITS::Header"
	unless UNIVERSAL::isa($arg, "Astro::FITS::Header");
    }
    $self->{FitsHdr} = $arg;
  }

  # Create a new fits object if we have not got one
  # Code cribbed from OMP::Info::Obs
  my $fits = $self->{FitsHdr};
  if( ! defined( $fits ) ) {

    # Note that the hdr() method calls the fits() method if
    # no hash exists. To prevent recursion problems we do not use
    # the accessor method here
    my $hdrhash = $self->{Header};
    if( defined( $hdrhash ) ) {

      my @items = map { new Astro::FITS::Header::Item( Keyword => $_,
                                                       Value => $hdrhash->{$_}
                                                     ) } keys (%{$hdrhash});

      # Create the Header object.
      $fits = new Astro::FITS::Header( Cards => \@items );

      $self->{FitsHdr} =  $fits;

      # And force the old header hash to be a tie derived from this
      # object [making sure that multi-valued headers are returned as an array]
      $fits->tiereturnsref(1);
      tie my %header, ref($fits), $fits;
      $self->{Header} = \%header;

    }
  }
  return $fits;
}

=item B<hdr>

This method allows specific entries in the header to be accessed.  In
general, this header is related to the actual header information
stored in the file. The input argument should correspond to the
keyword in the header hash.

  $tel = $Frm->hdr("TELESCOP");
  $instrument = $Frm->hdr("INSTRUME");

Can also be used to set values in the header.
A hash can be used to set multiple values (but does not overwrite
other keys).

  $Grp->hdr("INSTRUME" => "IRCAM");
  $Frm->hdr("INSTRUME" => "SCUBA", 
            "TELESCOP" => 'JCMT');

If no arguments are provided, the reference to the header hash
is returned.

  $Grp->hdr->{INSTRUME} = 'SCUBA';

The header can be populated from the file by using the readhdr()
method. If a FITS header object has been set via the C<fits>
method, a new header hash will be created automatically if one
does not exist already (via a tie).

=cut

sub hdr {
  my $self = shift;

  # If we have one argument we should read it and return the associated
  # value. If we have more than one argument will assume a hash has
  # been supplied and append it to the existing values.
  if (@_) {

    # Force a synch with the FITS header object if needed
    # Call with no arguments so there are no worries with
    # recursion loops.
    my $hdr = $self->hdr();

    if (scalar(@_) == 1) {
      # Return the value if we have a single argument
      my $key = shift;
      return $hdr->{$key};
    } else {

      # Since in most cases we will be processing fewer
      # headers than we already have, it is more efficient
      # to step through each header in turn rather than
      # doing a hash push: %a = (%a, %b) although this
      # has not been verified by benchmarks
      my %new = @_;
      for my $key (keys %new) {
	# print "Storing $new{$key} in key $key\n";
	$hdr->{$key} = $new{$key};
      }
    }
  } else {
    # No arguments, return the header hash reference
    # or tie it to the new one
    my $hdr = $self->{Header};
    if( ! defined( $hdr ) || scalar keys %$hdr == 0) {
      my $fits = $self->fits();
      if( defined( $fits ) ) {
	my $FITS_header = $fits;
	tie my %header, ref($FITS_header), $FITS_header;
	$self->{Header} = \%header;
      }
    }
    return $self->{Header};
  }
}

=item B<uhdr>

This method allows specific entries in the user-defined header to be 
accessed. The input argument should correspond to the keyword in the 
user header hash.

  $tel = $Grp->uhdr("Telescope");
  $instrument = $Frm->uhdr("Instrument");

Can also be used to set values in the header.
A hash can be used to set multiple values (but does not overwrite
other keys).

  $Grp->uhdr("Instrument" => "IRCAM");
  $Frm->uhdr("Instrument" => "SCUBA", 
             "Telescope" => 'JCMT');

If no arguments are provided, the reference to the header hash
is returned.

  $Frm->uhdr->{Instrument} = 'SCUBA';

=cut



sub uhdr {
  my $self = shift;

  # If we have one argument we should read it and return the associated
  # value. If we have more than one argument will assume a hash has
  # been supplied and append it to the existing values.
  if (@_) {
    if (scalar(@_) == 1) {
      my $key = shift;
      return $self->{UHeader}->{$key};
    } else {

      # Since in most cases we will be processing fewer
      # headers than we already have, it is more efficient
      # to step through each header in turn rather than
      # doing a hash push: %a = (%a, %b) although this
      # has not been verified by benchmarks
      my %new = @_;
      for my $key (keys %new) {
	# print "Storing $new{$key} in key $key\n";
	$self->{UHeader}->{$key} = $new{$key};
      }

    }
  } else {
    # No arguments, return the header hash reference
    return $self->{UHeader};
  }
}

=back

=head2 General Methods

=over 4

=item B<readhdr>

A method that is used to read header information from the group
file. This method does nothing by default since the base
class does not know the format of the file associated with an
object.

The calc_orac_headers() method is called automatically.

=cut

sub readhdr {
  my $self = shift;
  $self->calc_orac_headers;
  return;
}

=item B<translate_hdr>

Translates an ORAC-DR specific header (such as ORAC_TIME)
to the equivalent FITS header(s).

  %fits = $Frm->translate_hdr( "ORAC_TIME" );

In some cases a single ORAC-DR header can be decomposed into 
multiple FITS headers (for example for SCUBA, ORAC_TIME is
a combination of the UTDATE and UTSTART). The hash returned
by translate_hdr() will include all the key/value pairs required
to generate the ORAC header.

This method will be called automatically to update hdr() values
ORAC_ keywords are updated via uhdr().

Returns an empty list if no translation is available.

=cut

sub translate_hdr {
  my $self = shift;
  my $key = shift;
  return () unless defined $key;

  # Remove leading ORAC_
  $key =~ s/^ORAC_//;

  # Each translation is performed by an individual method
  # This adds a overhead for method lookups but hopefully
  # will lend itself to subclassing
  # The translate_hdr() method itself will then not need to be 
  # subclassed at all
  my $method = "_from_$key";
  # print "trying method translate $method\n";
  if ($self->can($method)) {
    return $self->$method();

  } else {
    return ();
  }
}

=item B<_from_*>

Methods to translate ORAC_ private headers to FITS headers
required by the instrument. This is the reverse of C<_to_*> called
from C<calc_orac_headers>.

These methods should only be called by C<translate_hdr>

Returns a hash containing the FITS key(s) and value(s).

   %fits = $Frm->_from_AIRMASS_START();

The method name does not include the ORAC_ prefix.

=item B<_to_*>

Methods to translate standard FITS headers to ORAC_ headers.
These methods should be called just from C<orac_calc_headers>.

Returns the translated value.

  $val = $Frm->_to_AIRMASS_START();

The method name does not include the ORAC_ prefix.

=cut

# Generate the methods automatically from a lookup table
# This only works with one-to-one mappings of keywords.

# This method generates all the internal methods
# Expects a hash ref as argument and simply does a name
# translation without any data processing
# The hash is keyed by the ORAC_ name (without the ORAC_ prefix
# (although that will be removed if it appears)
# This is a class method (no object required)
sub _generate_orac_lookup_methods {
  my $class = shift;
  my $lut = shift;

  # Have to go into a different package
  my $p = "{\n package $class;\n";
  my $ep = "\n}"; # close the scope

  # Loop over the keys to the hash
  for my $key (keys %$lut) {

    # Get the original FITS header name
    my $fhdr = $lut->{$key};

    # Remove leading ORAC_ if it is there since the method
    # should not include it
    $key =~ s/^ORAC_//;

    # prepend ORAC_ for the actual key name
    my $ohdr = "ORAC_$key";

    # print "Processing $key and $ohdr and $fhdr\n";

    # First generate the code to generate ORAC_ headers
    my $subname = "_to_$key";
    my $sub = qq/ $p sub $subname { \$_[0]->hdr(\"$fhdr\"); } $ep /;
    eval "$sub";

    # Now the from 
    $subname = "_from_$key";
    $sub = qq/ $p sub $subname { (\"$fhdr\", \$_[0]->uhdr(\"$ohdr\")); } $ep/;
    eval "$sub";

  }

}

=back

=head2 Private Methods

=over 4

=item B<stripfname>

Method to strip file extensions from the filename string. This method
is called by the file() method. For the base class this method
does nothing. It is intended for derived classes (e.g. so that ".sdf"
can be removed).

=cut


sub stripfname {

  my $self = shift;
  my $name = shift;
  return $name;
}


=back

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
