package ORAC::Convert;

=head1 NAME

ORAC::Convert - Methods for converting data formats

=head1 SYNOPSIS

  use ORAC::Convert

  $conv = new ORAC::Convert;
  $outfile = $conv->convert($infile, {IN => 'FITS', OUT => 'NDF'});

  $outfile = $conv->convert($infile, { OUT => 'NDF'});

  $outfile = $conv->fits2ndf($infile);

  $conv->infile($infile);
  $outfile = $conv->convert;  # uses infile()

=head1 

Provide a system for converting data formats. Currently the
only output format supported is NDF. The only input formats supported
are NDF (!) and FITS.

NDF format is used as the intermediate  format for all conversions
(should probably use PDLs as the intermediate format....)

Uses the Starlink CONVERT package (via monoliths).

=cut


use strict;
use Carp;
use vars qw/$VERSION/;

use File::Basename;  # Get file suffix

use ORAC::Print;
use ORAC::Msg::ADAM::Control;
use ORAC::Msg::ADAM::Task;
use ORAC::Constants qw/:status/;        #  Constants

$VERSION = '0.10';

=head1 METHODS

The following methods are provided:

=over 4

=item new()

Object constructor. Should always be used before initiating a conversion.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;
 
  my $conv = {};  # Anon hash
  
  $conv->{AMS} = undef;        # Messaging
  $conv->{ConvObjects} = {};   # Conversion objects - 1 per convert monolith
  $conv->{InFile} = undef;
  $conv->{OverWrite} = 0;      # Do not overwrite files of same name

  bless($conv, $class);

  # Check if $CONVERT_DIR exists
  unless (defined $ENV{CONVERT_DIR}) {
    orac_err("CONVERT_DIR not defined. Can not convert data\n");
    return undef;
  }


  # Start message system (should just return if already started)
  my $status = ORAC__OK;
  # This check is a bit dodgy. I add it to stop the error message
  # occuring concerning whether the AMS is currently running or not.
  $conv->{AMS} = new ORAC::Msg::ADAM::Control;
  $status = $conv->{AMS}->init;

  return undef if $status != ORAC__OK;
  return $conv;

}


=item infile

Method for storing or retreiving the current input filename.
Used by default if omitted from convert() methods.

=cut

sub infile {
  my $self = shift;
  if (@_) { $self->{InFile} = shift;  }
  return $self->{InFile};
}

=item overwrite

Method for storing or retreiving the flag governing whether
a file should be overwritten if it already exists.

If false, the file will be converted regardless.

=cut

sub overwrite {
  my $self = shift;
  if (@_) { $self->{OverWrite} = shift;  }
  return $self->{OverWrite};
}

=item objref

Hash containing convert task objects.

=cut

sub objref {
  my $self = shift;
 
  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{ConvObjects} = $arg;
  }
 
  return $self->{ConvObjects};
}



=item mon(name) 

Returns a ORAC::Msg::ADAM::Task object using a path of name_$$
in the messaging system.

Returns undef if a monolith can not be contacted or fails to start.

=cut

sub mon {
  my $self = shift;
  
  croak "Usage: Convert->mon(name)" unless scalar (@_) == 1;

  # Get the name
  my $mon = shift;
  
  # Append pid
  my $name = $mon . "_$$";

  # Now look up object in the message storage area
  my $obj;
  if (exists $ {$self->objref}{$name}) {
    return $ {$self->objref}{$name};
  } else {
    # Create a new one
    $obj = new ORAC::Msg::ADAM::Task($name, "$ENV{CONVERT_DIR}/$mon",
				     { MONOLITH => "$mon"}
				    );
    if ($obj->contactw) {
      $ {$self->objref}{$name} = $obj;
    } else {
      return undef;
    }

  }

}



=item convert (Filename, OptionsHashRef)

Convert a file to the format specified by options.

File is optional - uses infile() to retrieve the name if not specified.
The options hash is optional (assumed to be last argument). If not
specified the input format will be guessed and the output format
will be set to NDF.

Recongised keywords in the hash are:

  IN  => input format (NDF or FITS)
  OUT => desired output format (NDF)

If 'IN' is not specified it will try to derive the format from
name.

The output format is set to NDF if non-specified.

Returns the new filename (derived from the input filename).

Output filename is written to the current working directory of the
CONVERT monoliths (defaults to the CWD of the program when the
monoliths were launched - no attempt is made to correct the
CWD of the monoliths before conversion).

=cut

sub convert {
  my $self = shift;

  croak ('Usage: $obj->convert(filename, \%options)')
    unless scalar(@_) < 3;

  # Pop the options hash off the top
  my %options = ( OUT => 'NDF');
  if (ref($_[-1]) eq 'HASH') {
    my $href = pop;
    foreach my $key (keys %$href) {
      $options{uc($key)} = uc($$href{$key}); 
    }
  }

  # If we have any args left assume that it is the filename
  my $filename;
  if (@_) {
    $filename = shift;
    $self->infile($filename);
  } else {
    $filename = $self->infile($filename);
  }
  
  unless (exists $options{IN}) {
    # Input format not specified
    # guess from name
    $options{'IN'} = $self->guessformat;
  }

  # Guess will be undef if the format could not be determined
  # if that is the case return undef and raise an error
  unless (defined $options{'IN'}) {
    orac_err("Could not determine data format of $filename\n");
    return undef;
  }

  # If the input format is the same as the output just return
  # Make sure directory path is removed
  if ($options{'IN'} eq $options{OUT}) {
    my $out = (split(/\//,$filename))[-1];
    return $out;
  }

  # Set the overwrite flag
  $self->overwrite($options{OVERWRITE}) if exists $options{OVERWRITE};

  my $outfile = undef;
  # Now ask the relevant routine to convert first to NDF
  if ($options{'IN'} eq 'FITS') {
    $outfile = $self->fits2ndf;
  }

  # Now from NDF convert to the desired output format
  # NOT YET IMPLEMENTED

  # Return the name of the converted file
  # Make sure that we dont return a full path (the conversion occurred
  # in the current directory even if we read from a remote directory)


  return (split(/\//,$outfile))[-1];;

}


=item guessformat(name)

Given 'name' try to guess data format.

=cut

sub guessformat {
  my $self = shift;
  
  my $name;
  if (@_) {
    $name = shift;
  } else {
    $name = $self->infile;
  }

  # Check via file extension
  my @junk = split(/\./, $name);
  my $suffix = "." . $junk[-1];

  # Could also do this by checking the suffix AND trying to open
  # file (eg ndf_open or see if first line is SIMPLE = T)

  $suffix eq '.sdf' && ( return 'NDF'); # Could be DST or HDS container
  $suffix eq '.fits' && (return 'FITS');
  $suffix eq '.fit' && (return 'FITS');

  return undef;

}


=item fits2ndf

Convert a fits file to an NDF.
Returns the output name.

=cut

sub fits2ndf {
  my $self = shift;
  
  my $name;
  if (@_) {
    $name = shift;
  } else {
    $name = $self->infile;
  }

  # Generate an outfile
  my $out = $name;
  $out =~ s/\.fit.*$//;

  $out = (split(/\//,$out))[-1];

  my $ndf = $out . ".sdf";

  # Check the output file name and whether we are allowed to
  # overwrite it.
  if (-e $ndf && ! $self->overwrite) {
    # Return early
    orac_warn "The converted file ($ndf) already exists - won't convert again\n";
    return $ndf;
  }

  # Check to see if fits2ndf monolith is running
  my $status = ORAC__ERROR;
  if (defined $self->mon('fits2ndf')) {

    # Do the conversion
    $status = $self->mon('fits2ndf')->obeyw("fits2ndf","in=$name out=$out proexts profits fmtcnv='true'");

  }

  # Return the filename (append .sdf) if everything okay.
  if ($status == ORAC__OK) {
    return $ndf;
  } else {
    return undef;
  }

}




=back


=head1 SEE ALSO

The Starlink CONVERT package.

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=cut



1;

