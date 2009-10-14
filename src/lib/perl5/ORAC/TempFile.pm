package ORAC::TempFile;

=head1 NAME

ORAC::TempFile - generate temporary files for ORAC-DR

=head1 SYNOPSIS

  use ORAC::TempFile;

  $temp = new ORAC::TempFile;
  $temp = new ORAC::TempFile(0);
  $fname = $temp->file;
  print {$temp->handle} "Some temporary data";

  $temp->handle->close; # Close temporary file

  undef $temp;          # Close file and remove it


=head1 DESCRIPTION

Provide a simplified means of handling temporary files from within
ORAC-DR. The temporary file is automatically removed when the
object goes out of scope.

The temporary file name can also be used as a temporary name for
NDF files. NDF files (extension '.sdf') are automatically deleted
in addition to the temporary file created by this class.

=cut

use strict;
use warnings;
use Carp;
use File::Temp qw/ tempfile /;
use vars qw/$VERSION $DEBUG/;

use overload '""' => "STRINGIFY", fallback => 1;

$VERSION = '1.0';
$DEBUG = 0;

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructor

The following constructors are available:

=over 4

=item B<new>

Create a new instance of a B<ORAC::TempFile> object.

  $temp = new ORAC::TempFile;

If a false argument is supplied the temporary file
name will be allocated (and the file opened) but the
file itself will be closed before the new object is returned.
This is so that the temporary file name can be passed directly
to another process without wanting to write anything to the
file yourself (for example if you want to generate a file
in an external program and then read the results back into
perl).

  $temp = new ORAC::TempFile(0);

Returns 'undef' if the tempfile could not be created.
The file is opened for read/write with autoflush set to true.
The file should be closed (using the close() method on the
object file handle) before sending the file name to an external
process (unless a false argument is supplied to the constructor).

  $temp->handle->close;

An argument hash is also supported. These arguments are OPEN and
SUFFIX. OPEN is the equivalent of passing in a solitary false
argument. SUFFIX appends the given suffix to the temporary
filename. For example, to create a temporary file with a closed
filehandle and a .txt suffix, one would do:

  $temp = new ORAC::TempFile( OPEN => 0,
                              SUFFIX => '.txt' );

Note that if you pass in an argument hash you cannot have a solitary
false argument to return a closed file; if you wish to return a closed
file in conjunction with setting a suffix, you must use the OPEN named
argument.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Define the initial state
  my $tmp = {
             Handle => undef,
             File   => undef,
            };

  # Bless it
  bless $tmp, $class;

  # Now run the Initialise method
  $tmp->Initialise( @_ );

  # Return the object unless the Handle is undefined
  if (defined $tmp->{Handle}) {

    # Read any arguments - close the filehandle if false
    if (@_ == 1) {
      $tmp->handle->close unless $_[0];
    }
    return $tmp;
  }
  return;
}

=back

=head2 Accessor Methods


The following methods are available for accessing the
'instance' data.

=over 4

=item B<handle>

Return (or set) the file handle associated with the temporary
file.

  print {$tmp->handle} "some information\n";

=cut

sub handle {
  my $self = shift;
  $self->{Handle} = shift if @_;
  return $self->{Handle};
}


=item B<file>

Return the file name associated with the temporary file.

  $name = $tmp->file;

The file name is also returned on stringification of the object.

=cut

sub file {
  my $self = shift;
  $self->{File} = shift if @_;
  return $self->{File};
}

sub STRINGIFY {
  my $self = shift;
  return $self->file;
}

=back

=head2 Destructor

This section details the object destructor.

=over 4

=item B<DESTROY>

The destructor is run when the object goes out of scope
or no longer has any references to it. When called, the
temporary file is closed and unlinked. If necessary
and files of the same name but with a '.sdf' extension
are also unlinked. This allows the same class to be used
for temporary plain files and temporary NDF files.

No files are removed if the debugging flag ($DEBUG) is set to
true (the default is false)

=cut

sub DESTROY {
  local($., $@, $!, $^E, $?);
  my $self = shift;

  unless ($DEBUG) {
    # close file handle
    my $hdl = $self->handle;
    $hdl->close if defined $hdl;

    # Retrieve the file name and unlink
    my $name = $self->file;
    if (defined $name) {
      unlink $name;
      unlink $name . '.sdf';
    }
  }
}


=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are
aware of them.

=over 4

=item B<Initialise>

This method is used to initialise the object. It is called
automatically by the object constructor. It generates
a temporary file name and attempts to open it. If the
open is not successful the state of the object remains
unchanged. In general, this means that the object
constructor has failed.

=cut

sub Initialise {
  my $self = shift;

  my %args;
  if ( @_ > 1 ) {
    %args = @_;
  }

  # If the user supplied a directory, don't honour it.
  if ( defined( $args{'DIR'} ) ) {
    delete $args{'DIR'};
  }
  my $dir = $ENV{'ORAC_DATA_OUT'};

  # Get a temp file. File::Temp makes this painless
  my ($fh, $file) = tempfile( "oractempXXXXXX",
                              DIR => $dir,
                              %args,
                            );

  # Remove dots since NDF does not like them But have to be careful
  # that original directory path might contain a .  even if absolute,
  # and only do it if we don't have a SUFFIX parameter in %args.
  if ( ! defined( $args{'SUFFIX'} ) ) {
    substr($file,length($dir)) =~ s/\./_/g;
  }

  # Set autoflush
  $fh->autoflush(1);

  # Store the state
  $self->handle($fh);
  $self->file($file);

  return;
}


=back

=head1 GLOBAL VARIABLES

The following global variables are available.
They can be accessed directly or via Class methods of the same name.

=over 4

=item * $VERSION

The current version number of this module.

  $version = $ORAC::TempFile::VERSION;
  $version = ORAC::TempFile->VERSION;

=cut

sub VERSION { return $VERSION; }

=item * $DEBUG

Debugging flag. When this flag is set to true the temporary
files are not deleted by the object destructor. They can be
examined at a later time.

  $debug = ORAC::TempFile->DEBUG;
  ORAC::TempFile->DEBUG(1);
  $ORAC::TempFile::DEBUG = 0;

=cut

sub DEBUG {
  my $self = shift;
  $DEBUG = shift if @_;
  return $DEBUG;
}

=back

=head1 SEE ALSO

L<IO::File>, L<File::MkTemp>, L<POSIX/tmpnam()>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Science and Technology Facilities Council.
Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
