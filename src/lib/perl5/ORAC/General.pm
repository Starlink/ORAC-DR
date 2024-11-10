package ORAC::General;

=head1 NAME

ORAC::General - Simple perl subroutines that may be useful for primitives

=head1 SYNOPSIS

  use ORAC::General;

  $max = max(@values);
  $min = min(@values);
  $result = log10($value);
  $result = nint($value);
  $yyyymmdd = utdate;
  %hash = parse_keyvalues($string);
  @obs = parse_obslist($string);
  $result = cosdeg( 45.0 );
  $result = sindeg( 45.0) ;
  @dms = dectodms( $dec );

  print "Is a number" if is_numeric( $number );

=head1 DESCRIPTION

This module provides simple perl functions that are not available
from standard perl. These are available to all ORAC primitive writers,
but they are general in nature and have no connection to orac. Some of
these are used in the ORAC infastructure, so ORACDR does require this
library in order to run.


=cut

use strict;
use warnings;
use 5.006;
require Exporter;
use base qw/ Exporter /;
use vars qw/ @EXPORT /;
@EXPORT = qw( max min log10 nint utdate parse_keyvalues parse_obslist cosdeg
              sindeg dectodms hmstodec deg2rad rad2deg is_numeric
              write_file_list write_file_list_inout read_file_list
              hardlink oractime2mjd oractime2dt oractime2iso
              filter_quoted_string
           );

use Carp;
use vars qw/$VERSION/;

$VERSION = '1.0';


# Use POSIX so that I can get log10 support
# I realise that I can create a log10 function via natural logs
use POSIX qw//;
use Math::Trig qw/ deg2rad rad2deg /;
use Text::Balanced qw/ extract_bracketed extract_delimited /;
use Scalar::Util qw/ blessed /;
use DateTime;

=head1 SUBROUTINES

=over 4

=item B<cosdeg>

Return the cosine of the angle. The angle must be in degrees.

=cut

sub cosdeg {
  cos( deg2rad($_[0]) );
}

=item B<sindeg>

Return the sine of the angle. The angle must be in degrees.

=cut

sub sindeg {
  sin( deg2rad($_[0]) );
}

=item B<dectodms>

Convert decimal angle (degrees or hours) to degrees, minutes and seconds.
(or hours).

  ($deg, $min, $sec) = dectodms( $decimal );

=cut

sub dectodms {

  my $dec = shift;
  my @dms;
  my $neg = 0;
  if ( $dec < 0 ) {
    $neg = 1;
    $dec = - $dec;
  }
  $dms[ 0 ] = int( $dec );
  $dms[ 1 ] = int( ( $dec - int( $dec ) ) * 60 );
  $dms[ 2 ] = ( ( $dec - $dms[ 0 ] ) * 60 -
                int( ( $dec - $dms[ 0 ] ) * 60 ) ) * 60;
  if ( $neg ) {
    $dms[0] *= -1;
  }
  return @dms;
}

=item B<hmstodec>

Convert hours:minutes:seconds to decimal hours.

  my $hms = "23:58:01.23";
  my $dec = hmstodec($hms);

=cut

sub hmstodec {

  my $string = shift;

  $string =~ m/\s*(\d{1,2})[: ]([0-5]?\d)[: ]([0-5]?\d)(\.\d{1,3})?\s*/;

  my $secs = (defined $4) ? $3+$4 : $3;
  my $float = ($1+($2/60.0)+(($secs)/3600.0));
  my $sign = ($string =~ m/^\s*-/ ) ? -1.0 : +1.0;
  $float *= $sign;

  return $float;

}

=item B<is_numeric>

Determine whether the supplied argument is a number or not.
Returns true if it is and false otherwise.

=cut

# See Perl Cookbook example 2.1

sub is_numeric {
  defined scalar getnum($_[0]);
}

sub getnum {
  my $str = shift;
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  $!=0;
  my ($num, $unparsed) = POSIX::strtod($str);
  if (($str eq '') || ($unparsed != 0) || $!) {
    return;
  } else {
    return $num;
  }
}


=item B<min>

Find the minimum value of an array. Can also be used to find
the minimum of a list of scalars since arguments are passed into
the subroutine in an array context.

  $min = min(@values);
  $min = min($a, $b, $c);

=cut

sub min {
  my $zmin = $_[0];
  foreach (@_) {
    ($_ < $zmin) && ($zmin = $_);
  }
  return $zmin;
}

=item B<max>

Find the maximum value of an array. Can also be used to find
the maximum of a list of scalars since arguments are passed into
the subroutine in an array context.

  $max = max(@values);
  $max = max($a, $b, $c);

=cut

sub max {
  my $zmax = $_[0];
  foreach (@_) {
    ($_ > $zmax) && ($zmax = $_);
  }
  return $zmax;
}


=item B<log10>

Returns the logarithm to base ten of a scalar.

  $value = log10($number);

Currently uses the implementation of log10 found in the
POSIX module


=cut


sub log10 {

  my $in = shift;

  return POSIX::log10($in);
}
;


=item B<nint>

Return the nearest integer to a supplied floating point
value. 0.5 is rounded up.

=cut

sub nint {
  my $value = shift;

  if ($value >= 0) {
    return (int($value + 0.5));
  } else {
    return (int($value - 0.5));
  }
}
;

=item B<utdate>

Return the UT date (strictly, GMT) date in the format yyyymmdd

=cut

sub utdate {

  my ($day,$month,$year) = (gmtime)[3..5];
  $month++;
  $year += 1900;
  return sprintf( "%04d%02d%02d", $year, $month, $day );

}

=item B<parse_keyvalues>

Takes a string of comma-separated key-value pairs and return a hash.

  %hash = parse_keyvalues("a=1,b=2,C=3");

The keys are down-cased.

Values can be quoted or bracketed. If values include commas themselves
they will be returned as array references, e.g.

   "a=1,b=2,3,c='4,5',d=[1,2,3,4],e=[5]"

will return the following.

    a => 1,
    b => [2,3],
    c => [4,5],
    d => [1,2,3,4],
    e => 5,

Note that delimiters are removed from the values and that if only a
single element is quoted it will be returned as a scalar string rather
than an array.

=cut


sub parse_keyvalues {

  my ($string) = shift;
  my %hash;

  # Split on equals sign first so that we can trap a="b,c"
  my @split = split('=',$string);

  my $current_key = $split[0];

  for my $i (1..$#split) {

    my $value;
    my $next_key;

    # Count the number of commas
    my $ncomma = ( $split[$i] =~ tr|,|,|);

    # Do we have a delimiting or bracketing character
    if ($split[$i] =~ /^[\'\"\[\{\(]/ ) {
      my ($extract, $remainder);
      if ($split[$i] =~ /^[\'\"]/ ) {
        # Delimiting character
        ($extract, $remainder) = extract_delimited( $split[$i],
                                                    substr($split[$i],0,1));

      } elsif ($split[$i] =~ /^[\[\(\{]/ ) {
        # bracketing character
        ($extract, $remainder) = extract_bracketed( $split[$i], '(){}[]<>' );

      }

      # remove the brackets/delimiters
      $extract =~ s/^.//;
      $extract =~ s/.$//;

      # print "\t extracted $extract with remainder $remainder\n";

      # Now we need to split the extracted string on commas
      # and convert to an array if we have more than one
      my @values = split(/,/,$extract);
      $value = ( scalar(@values) > 1 ?  \@values : $values[0] );

      # and calculate the next key
      $next_key = $remainder;
      $next_key =~ s/^,// if defined $next_key;

    } elsif ($ncomma > 1 || ( $ncomma ==1 && $i == $#split)) {
      # We have a normal comma separated list
      # Either because we have a comma in the list and this is the
      # last entry (and so can not be a key specification) or we
      # have more than one comma in the string

      # Just split on comma
      my @parts = split(',',$split[$i]);

      # Get the next key if we are not the last entry in the list
      $next_key = pop(@parts) if $i != $#split;

      # Convert to array or single value
      $value = ( scalar(@parts) > 1 ? \@parts : $parts[0]);

    } else {
      # This is a straight string so we need to split on ,
      ($value, $next_key) = split(',', $split[$i]);
    }

    # Store the current value and set the next key
    $hash{lc($current_key)} = $value;
    $current_key = $next_key;
  }

  return %hash;
}


=item B<parse_obslist>

Converts a comma separated list of observation numbers (as supplied
on the command line for the -list option) and converts it to
an array of observation numbers. Colons are treated as range arguments.

For example,

   "5,9:11"

is converted to

   (5,9,10,11)

=cut

# Argument disentanglement

# Parse the observation list that is entered with the -list
# option. This is a comma separated list of numbers.
# Ranges can be specified with colons

# Returns an array of observation numbers.

sub parse_obslist {

  my $obslist = shift;
  my @obs = ();

  # Split on the comma
  @obs = split(",",$obslist);

  # Now go through each entry and see if we can expand on :
  # a:b expands to a..b.
  for (my $i = 0; $i <= $#obs; $i++) {

    $obs[$i] =~ /:/ && do {
      my ($start, $end) = split ( /:/, $obs[$i]);

      # Generate the range
      my @junk = $start..$end;

      # Splice into @obs
      splice(@obs, $i, 1, @junk);

      # Increment the counter to take into account the
      # new additions (since we know that @junk does not contain
      # colons. We dont need this - especially if we want to parse
      # The expanded array
      $i += $#junk;

    }

  }

  return @obs;
}

=item B<convert_args_to_string>

Convert a hash as returned by
ORAC::Recipe::PrimitiveParser->_parse_prim_arguments into a string
that can be output for logging.

  my $str = convert_args_to_string( $args );

Frame objects passed in will be stringified to "Frame::<class>". Group
objects passed in will be stringified to "Group::<class>". Undefined
variables will be stringified to "undef".

=cut

sub convert_args_to_string {
  my %args = @_;
  if ( ! %args ) {
    return "";
  }
  my @strs;
  foreach my $key ( keys %args ) {
    if ( ! defined( $args{$key} ) ) {
      push @strs, "$key=undef";
    } elsif ( UNIVERSAL::isa( $args{$key}, "ORAC::Frame" ) ||
              UNIVERSAL::isa( $args{$key}, "ORAC::Group" ) ) {
      my $str = "$args{$key}";
      $str =~ s/^ORAC:://;
      $str =~ s/=[\w()]+$//;
      push @strs, "$key=$str";
    } elsif ( UNIVERSAL::isa( $args{$key}, "ORAC::TempFile" ) ) {
      push @strs, "$key=" . $args{$key}->file;
    } elsif ( UNIVERSAL::isa( $args{$key}, "HASH" ) ) {
      if ( scalar keys %{$args{$key}} <= 5 ) {
        push @strs, "$key={" . ( join ",", map { "$_=>".(defined $args{$key}{$_} ? $args{$key}{$_} : "undef") } keys %{$args{$key}} ) . "}";
      } else {
        push @strs, "$key={" . ( scalar keys %{$args{$key}} ) . " element hash}";
      }
    } elsif ( UNIVERSAL::isa( $args{$key}, "ARRAY" ) ) {
      if ( scalar @{$args{$key}} <= 5 ) {
        push @strs, "$key=[" . ( join ",", @{$args{$key}} ) . "]";
      } else {
        push @strs, "$key=[" . ( scalar @{$args{$key}} ) . " element array]";
      }
    } else {
      push @strs, "$key=$args{$key}";
    }
  }

  return join( " ", @strs );

}

=item B<read_file_list>

Given either a filename or an ORAC::TempFile object, read the contents
(usually filenames) and return a list. Blank lines and anything after
 a # comment character are ignored.

  @files = read_file_list( $listfile );

Returns array or array reference depending on calling context. Returns
undef if the given file does not exist.

=cut

sub read_file_list {
  my $intmp = shift;

  my $fh;
  my $opened = 0;
  if (blessed($intmp) && $intmp->can( "handle" )) {
    $fh = $intmp->handle;
    seek( $fh, 0, 0); # seek to start of file
  } else {
    if ( ! open $fh, "<", $intmp ) {
      return undef;
    }
    $opened = 1;
  }

  # Strip comments and only store non-blank lines
  my @contents = grep {
    length($_) > 0
  } map {
    chomp;      # Newline
    s/\#.*//;   # Trailing comments
    s/\s*$//;   # Trailing whitespace
    $_
  } <$fh>;

  close $fh if $opened;

  return (wantarray ? @contents : \@contents);
}

=item B<write_file_list>

Given an array of file names, open a temp file, write the filenames
to it and return the name of the file. The returned object stringifies
to the actual filename. It must be returned as an object so that
the temp file will be deleted automatically when the variable
goes out of scope.

  $fobject = write_file_list( $Frm->files );

Suitable for creating a file to be used for Starlink application
group parameters.

Note that overwriting the return value (by, say, string concatenation)
runs the destructor which unlinks the temporary file.

=cut

sub write_file_list {
  my @files = @_;
  my $intmp = ORAC::TempFile->new();
  for my $f (@files) {
    print {$intmp->handle} "$f\n";
  }
  close($intmp->handle);
  return $intmp;
}

=item B<write_file_list_inout>

Write an input indirection file and an output indirection file using the
supplied file suffix.

  ($in, $out, @outfiles) = write_file_list_inout( $Frm, "_al" );

The first argument is the frame or group object that will be used
for the inout() method and the second argument is the suffix to
be supplied to the inout() method. The names of the derived output files
are returned in the list. The object is not updated automatically.

If the third (optional) argument
is true the output files will be pushed onto the intermediates
array associated with the supplied frame/group object. This ensures
the files will be cleared up even if they are not output from a
primitive. If istmp is true, the output files are not returned to
the caller.

 ($in, $out) = write_file_list_inout( $Frm, "_al", 1);

=cut

sub write_file_list_inout {
  my $Obj = shift;
  my $suffix = shift;
  my $istmp = shift;

  # input files are easy
  my $infiles = write_file_list( $Obj->files );

  # output files need to be calculated using inout()
  my @outfiles = map { scalar $Obj->inout($suffix, $_ ) } (1..$Obj->nfiles);

  # write to group file
  my $outfiles = write_file_list( @outfiles );

  if ($istmp) {
    # store on intermediates if temporary
    $Obj->push_intermediates( @outfiles );
    return ($infiles, $outfiles);
  } else {
    return ($infiles, $outfiles, @outfiles);
  }
}

=item B<hardlink>

Create a hard link from an input file to an output file.

  $status = hardlink( $file, $link );

If $out exists, then it will be overwritten by the link.

Returns 1 if successful, 0 otherwise, and puts the error code into $!.

=cut

sub hardlink {
  my $file = shift;
  my $link = shift;

  if ( ! defined( $file ) ||
       ! defined( $link ) ) {
    $! = "Must define both file and link to hardlink()";
    return 0;
  }

  if ( -e $link ) {
    my $unlinkstatus = unlink( $link );
    if ( ! $unlinkstatus ) {
      return $unlinkstatus;
    }
  }
  my $linkstatus = link( $file, $link );
  return $linkstatus;
}

=item B<oractime2mjd>

Convert the standard ORACTIME format date (YYYYMMDD.frac) to
a modified Julian day.

  $mjd = oractime2mjd( $oractime );

=cut

sub oractime2mjd {
  my $dt = oractime2dt( $_[0] );
  return $dt->mjd if defined $dt;
  return 0.0;
}

=item B<oractime2iso>

Convert the standard ORACTIME format date (YYYYMMDD.frac) to
an ISO format string.

  $iso = oractime2iso( $oractime );

=cut

sub oractime2iso {
  my $dt = oractime2dt( $_[0] );
  return $dt->datetime if defined $dt;
  return "0000-00-00T00:00:00";
}

=item B<oractime2dt>

Convert the standard ORACTIME format date (YYYYMMDD.frac) to
a DateTime object.

  $dt = oractime2dt( $oractime );

=cut

sub oractime2dt {
  my $oractime = shift;
  my $dt;

  if ($oractime =~ /(\d{4})(\d{2})(\d{2})(\..*)/) {
    my $yy = $1;
    my $mm = $2;
    my $dd = $3;
    my $frac = $4;
    $dt = DateTime->new(
                        year => $yy,
                        month => $mm,
                        day => $dd,
                        time_zone => 'UTC');

    # Ignore leap seconds
    my $daysec = 86_400 * $frac;
    $dt->add( seconds => $daysec );
  }
  return $dt;
}

=item B<filter_quoted_string>

Prepare a string for use in Starlink command lines,
such that the string may be passed to a character parameter without
losing any quotation marks within the string.  This will typically be
passed to an NDF character component.

Performs this by doubling any quotation marks present
within the string, and escaping these too, if necessary.  This should
be used where the string is a priori unknown and may contain quotes
such as those to represent arcseconds and arcminutes, or a possessive
like "Barnard's Loop".  A common example is a user-defined object
name.

    $filtered = filter_quoted_string($string, $single);

C<$single> should be true if the string has been wrapped in single quotes.
For example,

    my $title = '$object offset by 10"';


Otherwise it is assumed to have been enclosed in double quotes.
For example,

    my $title = "Halley's Comet";

=cut

sub filter_quoted_string {
    my $string = shift;
    my $single = shift;

    # Replace quotes to preserve the string when passing it to a Starlink
    # application.  Double the quotation marks but also escape when the
    # quote is also that being used to delimit the string in the calling
    # primitive.
    if ($single) {
        $string =~ s/"/""/g;
        $string =~ s/'/\\'\\'/g;
    }
    else {
        $string =~ s/'/''/g;
        $string =~ s/"/\\"\\"/g;
    }

    return $string;
}

=back

=head1 SEE ALSO

L<POSIX>,
L<List::Util>,
L<Math::Trig>

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt> and
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Paul Hirst E<lt>p.hirst@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Science and Technology Facilities Council.
Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
