package ORAC::Frame;

=head1 NAME

ORAC::Frame - base class for dealing with observation frames in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame;

  $Frm = new ORAC::Frame("filename");
  $Frm->file("prefix_flat");
  $num = $Frm->number;  


=head1 DESCRIPTION

This module provides the basic methods available to all B<ORAC::Frame>
objects. This class should be used when dealing with individual
observation files (frames).

=cut

use 5.006;
use strict;
use warnings;
use Carp;
use Starlink::Versions qw/ starversion /;
use vars qw/$VERSION/;
use Astro::FITS::Header;

use ORAC::Print;
use ORAC::Constants;

use ORAC::BaseFile;
use base qw/ ORAC::BaseFile /;

$VERSION = sprintf("%d", q$Revision$ =~ /(\d+)/);

=head1 PUBLIC METHODS

The following methods are available in this class:

=head2 Constructors

The following constructors are available:

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame> object.  This method also
takes optional arguments: if 1 argument is supplied it is assumed to
be the name of the raw file associated with the observation.  If 2
arguments are supplied they are assumed to be the raw file prefix and
observation number.  In any case, all arguments are passed to the
configure() method which is run in addition to new() when arguments
are supplied.  The object identifier is returned.

   $Frm = new ORAC::Frame;
   $Frm = new ORAC::Frame("file_name");
   $Frm = new ORAC::Frame("UT", "number");

The base class constructor should be invoked by sub-class constructors.
If this method is called with the last argument as a reference to
a hash it is assumed that this hash contains extra configuration
information ('instance' information) supplied by sub-classes.

Note that the file format expected by this constructor is actually the
required format of the data (as returned by C<format()> method) and not
necessarily the raw format.  ORAC-DR will pre-process the data with
C<ORAC::Convert> prior to passing it to this constructor.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # see if we have been given any arguments from subclass
  my ($defaults, $args) = $class->_process_constructor_args({
                                                             Group => undef,
                                                             Recipe => undef,
                                                             IsGood => 1,
                                                             Nsubs => undef,
                                                             RawFixedPart => undef,
                                                             RawSuffix => undef,
                                                             TempRaw => [],
                                                            }, @_ );

  # call base class constructor
  return $class->SUPER::new( @$args, $defaults );
}

=head2 Accessor Methods

The following methods are available for accessing the 
'instance' data.

=over 4

=cut

# Create some methods to access "instance" data
#
# With args they set the values
# Without args they only retrieve values

=item B<group>

This method returns the group name associated with the observation.

  $group_name = $Frm->group;
  $Frm->group("group");

This can be configured initially using the findgroup() method.
Alternatively, findgroup() is run automatically by the configure()
method.

=cut

sub group {
  my $self = shift;
  if (@_) { $self->{Group} = shift;}
  return $self->{Group};
}

=item B<is_frame>

Whether or not the current object is an ORAC::Frame object.

  $is_frame = $self->is_frame;

Returns 1.

=cut

sub is_frame {
  return 1;
}

=item B<isgood>

Flag to determine the current state of the frame. If isgood() is true
the Frame is valid. If it returns false the frame object may have a
problem (eg the recipe responsible for processing the frame failed to
complete).

This flag is used by the B<ORAC::Group> class to determine membership.

=cut

sub isgood {
  my $self = shift;
  if (@_) { $self->{IsGood} = shift;  }
  $self->{IsGood} = 1 unless defined $self->{IsGood};
  return $self->{IsGood};
}

=item B<nsubs>

Return the number of sub-frames associated with this frame.

nfiles() should be used to return the current number of sub-frames
associated with the frame (nsubs usually only reports the number given
in the header and may or may not be the same as the number of
sub-frames currently stored)

Usually this value is set as part of the configure() method from the
header (using findnsubs()) or by using findnsubs() directly.

=cut

sub nsubs {
  my $self = shift;
  if (@_) { $self->{Nsubs} = shift; };
  return $self->{Nsubs};
}

=item B<rawfixedpart>

Return (or set) the constant part of the raw filename associated
with the raw data file. (ie the bit that stays fixed for every 
observation)

  $fixed = $self->rawfixedpart;

=cut

sub rawfixedpart {
  my $self = shift;
  if (@_) { $self->{RawFixedPart} = shift; }
  return $self->{RawFixedPart};
}

=item B<rawformat>

Data format associated with the raw() data file.
Usually one of 'NDF', 'HDS' or 'FITS'. This format should be
recognisable by C<ORAC::Convert>.

=cut

sub rawformat {
  my $self = shift;
  if (@_) { $self->{RawFormat} = shift; }
  return $self->{RawFormat};
}

=item B<rawsuffix>

Return (or set) the file name suffix associated with
the raw data file.

  $suffix = $self->rawsuffix;

=cut

sub rawsuffix {
  my $self = shift;
  if (@_) { $self->{RawSuffix} = shift; }
  return $self->{RawSuffix};
}

=item B<recipe>

This method returns the recipe name associated with the observation.
The recipe name can be set explicitly but in general should be
set by the findrecipe() method.

  $recipe_name = $Frm->recipe;
  $Frm->recipe("recipe");

This can be configured initially using the findrecipe() method.
Alternatively, findrecipe() is run automatically by the configure()
method.

=cut

sub recipe {
  my $self = shift;
  if (@_) { $self->{Recipe} = shift;}
  return $self->{Recipe};
}

=item B<tempraw>

An array of flags, one per raw file, indicating whether the raw
file is temporary, and so can be deleted, or real data (don't want
to delete it).

  $Frm->tempraw( @istemp );
  @istemp = $Frm->tempraw;

If a single value is given, it will be applied to all raw files

  $Frm->tempraw( 1 );

In scalar context returns true if all frames are temporary,
false if all frames are permanent and undef if some frames are temporary
whilst others are permanent.

  $alltemp = $Frm->tempraw();

=cut

sub tempraw {
  my $self = shift;
  if (@_) {
    my @rawfiles = $self->raw;
    my @flags;
    if (scalar(@_) == 1) {
      @flags = map { $_[0] } @rawfiles;
    } else {
      @flags = @_;
      if (@flags != @rawfiles) {
        croak "Number of tempraw flags (".@flags.") differs from number of registered raw files (".@rawfiles.")\n";
      }
    }
    @{$self->{TempRaw}} = @flags;
  }

  if (wantarray) {
    # will be empty if nothing specified so that will default to
    # undef if the array is read
    return @{$self->{TempRaw}};
  } else {
    my $istemp = 0;
    my $isperm = 0;
    for my $f (@{$self->{TempRaw}}) {
      if ($f) {
        $istemp = 1;
      } else {
        $isperm = 1;
      }
    }
    if ($istemp && $isperm) {
      return;
    } elsif ($istemp) {
      return 1;
    } else {
      # Default case if no tempraw has been specified
      return 0;
    }
  }
}

=back

=head2 General Methods

The following methods are provided for manipulating
B<ORAC::Frame> objects:

=over 4


=item B<configure>	 

This method is used to configure the object. It is invoked	 
automatically if the new() method is invoked with an argument. The	 
file(), raw(), readhdr(), findgroup(), findrecipe and findnsubs()	 
methods are invoked by this command. Arguments are required.  If there	 
is one argument it is assumed that this is the raw filename. If there	 
are two arguments the filename is constructed assuming that argument 1	 
is the prefix and argument 2 is the observation number.	 

  $Frm->configure("fname");	 
  $Frm->configure("UT","num");	 

Multiple raw file names can be provided in the first argument using	 
a reference to an array.	 

=cut	 
	 
sub configure {	 
  my $self = shift;	 
  my @args = @_;

  # if we have two arguments we need to convert to a single
  # argument and pass to base method
  if (scalar(@args) == 2) {
    my @files = ( $self->file_from_bits(@args) );
    @args = \@files;
  }

  # call base configure
  $self->SUPER::configure( @args );

  # Set the raw data file name from the files list
  $self->raw($self->files);

  # Find the group name and set it	 
  $self->findgroup;	 

  # Find the recipe name	 
  $self->findrecipe;	 

  # Find nsubs	 
  $self->findnsubs;	 

  # Return something	 
  return 1;	 
}

=item B<data_detection_tasks>

When the 'task' looping scheme is enabled, this method returns the name
of the remote task that should be queried for new data. These task names
must be registered with the C<ORAC::Inst::Defn> module.

  @tasks = $Frm->data_detection_tasks();

Returns an empty list in the base class.

=cut

sub data_detection_tasks {
  return ();
}

=item B<erase>

Erase the current file from disk.

  $Frm->erase($i);

The optional argument specified the file number to be erased.
The argument is identical to that given to the file() method.
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

Note that the file() method is not modified to reflect the
fact the the file associated with it has been removed from disk.

This method is usually called automatically when the file()
method is used to update the current filename and the nokeep()
flag is set to true. In this way, temporary files can be removed
without explicit use of the erase() method. (Just need to
use the nokeep() method after the file() method has been used
to update the current filename).

=cut

sub erase {
  my $self = shift;

  # Retrieve the necessary frame name
  my $file = $self->file(@_);

  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;
}


=item B<file_exists>

Method to determine whether the Frame file() exists on disk or not.
Returns true if the file is there, false otherwise. Effectively
equivalent to using C<-e> but allows for the possibility that the
information stored in file() does not directly relate to the
file as stored on disk (e.g. a .sdf extension). The base class is
very simplistic (ie does not assume extensions).

  $exists = $Frm->file_exists($i)

The optional argument refers to the file number.

=cut

sub file_exists {
  my $self = shift;
  if (-e $self->file(@_)) {
    return 1;
  }
  return 0;
}



=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

=cut

sub file_from_bits {

  # Tim decrees that this must be subclassed.
  die "The base class version of file_from_bits() should not be used\n -- please subclass this method\n";
}

sub file_from_bits_extra {
  my $self = shift;
  return;
}

=item B<findgroup>

Returns group name from header.  If we cannot find anything sensible,
we return 0.  The group name stored in the object is automatically
updated using this value.

=cut

sub findgroup {

  my $self = shift;

  my $hdrgrp = $self->hdr('GRPNUM');
  my $amiagroup;

  if ($self->hdr('GRPMEM')) {
    $amiagroup = 1;
  } elsif (!defined $self->hdr('GRPMEM')){
    $amiagroup = 1;
  } else {
    $amiagroup = 0;
  }

  # Is this group name set to anything useful
  if (!$hdrgrp || !$amiagroup ) {
    # if the group is invalid there is not a lot we can do
    # so we just assume 0
    $hdrgrp = 0;
  }

  $self->group($hdrgrp);

  return $hdrgrp;

}

=item B<findnsubs>

Find the number of sub-frames associated with the frame by looking in
the header. Usually run by configure().

In the base class this method looks for a header keyword of 'NSUBS'.

  $nsubs = $Frm->findnsubs;

The state of the object is updated automatically.

=cut

sub findnsubs {
  my $self = shift;
  my $nsubs = $self->hdr->{N_SUBS};
  $self->nsubs($nsubs);
  return $nsubs
}

=item B<findrecipe>

Method to determine the recipe name that should be used to reduce the
observation.  The default method is to look for an "ORAC_DR_RECIPE" entry
in the user header. If one cannot be found, we assume QUICK_LOOK.

  $recipe = $Frm->findrecipe;

The object is automatically updated to reflect this recipe.

=cut


sub findrecipe {
  my $self = shift;

  my $recipe = $self->uhdr('ORAC_DR_RECIPE');

  # Check to see whether there is something there
  # if not try to make something up

  if (!defined($recipe) or $recipe !~ /./) {
    orac_warn "Cannot determine recipe - defaulting to QUICK_LOOK\n";
    $recipe = 'QUICK_LOOK';
  }

  # Update
  $self->recipe($recipe);

  return $recipe;
}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This method should be implemented by a sub-class.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  die "The base class version of flag_from_bits() should not be used\n -- please subclass this method\n";

}


=item B<gui_id>

Returns the identification string that is used to compare the
current frame with the frames selected for display in the
display definition file.

Arguments:

 number - the file number (as accepted by the file() method)
          Starts counting at 1. If no argument is supplied
          a 1 is assumed.

To return the ID associated with the second frame:

 $id = $Frm->gui_id(2);

If nfiles() equals 1, this method returns everything after the last
suffix (using an underscore) from the filename stored in file(1). If
nfiles E<gt> 1, this method returns everything after the last
underscore, prepended with 's$number'. ie if file(2) is test_dk, the
ID would be 's2dk'; if file() is test_dk (and nfiles = 1) the ID would
be 'dk'. A special case occurs when the suffix is purely a number (ie
the entire string matches just "\d+"). In that case the number is
translated to a string "num" so the second frame in "c20010108_00024"
would return "s2num" and the only frame in "f2001_52" would return
"num".

Returns C<undef> if the file name is not defined.

=cut

sub gui_id {
  my $self = shift;

  # Read the number
  my $num = 1;
  if (@_) { $num = shift; }

  # Retrieve the Nth file name (start counting at 1)
  my $fname = $self->file($num);
  return unless defined $fname;

  # Split on underscore
  my (@split) = split(/_/,$fname);
  my ($junk, $fsuffix) = $self->_split_fname( $fname );
  @split = @$junk;

  my $id = $split[-1];

  # If we have a number translate to "num"
  $id = "num" if ($id =~ /^\d+$/);

  # Find out how many files we have
  my $nfiles = $self->nfiles;

  # Prepend wtih s$num if nfiles > 1
  # This is to make it simple for instruments that only ever
  # store one frame (eg UFTI)
  $id = "s$num" . $id if $nfiles > 1;

  return $id;

}

# Supply a method to return the number associated with the observation

=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number at the end of the raw data
filename.  For example a number can be extracted from strings of the
form textNNNN.sdf or textNNNN, where NNNN is a number (leading zeroes
are stripped) but not textNNNNtext (number must be followed by a decimal
point or nothing at all).

  $number = $Frm->number;

The return value is -1 if no number can be determined.

As an aside, an alternative approach for this method (especially
in a sub-class) would be to read the number from the header.

=cut


sub number {

  my $self = shift;

  my ($number);

  # Get the number from the raw data
  # Assume there is a number at the end of the string
  # (since the extension has already been removed)
  # Leading zeroes are dropped

  my $raw = $self->raw;
  if (defined $raw && $raw =~ /(\d+)(\.\w+)?$/) {
    # Drop leading 00
    $number = $1 * 1;
  } else {
    # No match so set to -1
    $number = -1;
  }

  return $number;

}

=item B<pattern_from_bits>

Determine the pattern for the raw filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $pattern = $Frm->pattern_from_bits($prefix, $obsnum);

Returns a regular expression object.

=cut

sub pattern_from_bits {

  # Tim decrees that this must be subclassed.
  die "The base class version of pattern_from_bits() should not be used\n -- please subclass this method\n";
}

=item B<template>

Method to change the current filename of the frame (file())
so that it matches a template. e.g.:

  $Frm->template("something_number_flat");

Would change the first file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

  $Frm->template("something_number_dark", 2);

would change the second filename to match "something_number_dark".
The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

The Nth filename is modified (ie file(N)).
There are no return arguments.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $fnum = 1;
  if (@_) { $fnum = shift; };

  my $num = $self->number;
  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($fnum, $template);

}

=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2007 Particle Physics and Astronomy Research
Council. All Rights Reserved.

Copyright (C) 2007 Science and Technology Facilities Council.  All
Rights Reserved.

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

