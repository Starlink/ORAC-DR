package ORAC::Frame::CGS4;

=head1 NAME

ORAC::Frame::UKIRT - CGS4 class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::CGS4;

  $Frm = new ORAC::Frame::CGS4("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to CGS4. It provides a class derived from B<ORAC::Frame::UKIRT>.
All the methods available to B<ORAC::Frame::UKIRT> objects are available
to B<ORAC::Frame::CGS4> objects. Some additional methods are supplied.

=cut
 
# A package to describe a UKIRT group object for the
# ORAC pipeline
 
use 5.004;
use ORAC::Frame::UKIRT;
 
# Let the object know that it is derived from ORAC::Frame;
#@ORAC::Frame::CGS4::ISA = qw/ORAC::Frame::UKIRT/;
use base  qw/ORAC::Frame::UKIRT/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# standard error module and turn on strict
use Carp;
use strict;
 
# For reading the header
use NDF;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame::UKIRT.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::UKIRT object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::CGS4;
   $Frm = new ORAC::Frame::CGS4("file_name");
   $Frm = new ORAC::Frame::CGS4("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'c' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;
  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('c');
  $self->rawsuffix('.sdf');
 
  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;
 
  return $self;
}


=back

=head2 General Methods

=over 4

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), findgroup(), findnsubs() and findrecipe()
methods are invoked by this command. Arguments are required.  If there
is one argument it is assumed that this is the raw filename. If there
are two arguments the filename is constructed assuming that arg 1 is
the prefix and arg2 is the observation number.

  $Frm->configure("fname");
  $Frm->configure("UT","num");

=cut

sub configure {
  my $self = shift;

  # If two arguments (prefix and number) 
  # have to find the raw filename first
  # else assume we are being given the raw filename
  my $fname;
  if (scalar(@_) == 1) {
    $fname = shift;
  } elsif (scalar(@_) == 2) {
    $fname = $self->file_from_bits(@_);
  } else {
    croak 'Wrong number of arguments to configure: 1 or 2 args only';
  }

  # Set the filename

  $self->file($fname);

  # Set the raw data file name

  $self->raw($fname);

  # Populate the header
  # for hds container set header NDF to be in the .header extension
  my $hdr_ext = $self->file.".header";

  $self->readhdr($hdr_ext);

  # Find the group name and set it
  $self->findgroup;

  # Find the recipe name
  $self->findrecipe;

  # Set the file method to the various components
  $self->findnsubs;

  # Return something
  return 1;
}


=item B<findnsubs>

This method returns the number of NDFs found in an HDS container.
This method assumes that there is a .HEADER component and removes
1 from the total count.

  $ncomp = $Frm->findnsubs;

The header is updated.

=cut

sub findnsubs {
		  
  my $self = shift;
  
  my $file = shift;
  
  my ($loc,$status,$ncomp);
  
  unless (defined $file) {
    $file = $self->file;
  }
  
  # Now need to find the NDFs in the output HDS file
  $status = &NDF::SAI__OK;
  hds_open($file, 'READ', $loc, $status);
  dat_ncomp($loc, $ncomp, $status);
  dat_annul($loc, $status);
		  
  unless ($status == &NDF::SAI__OK) {
    orac_err("Can't open $file for nsubs");
    return 0;
  }

  $ncomp--;
  $self->nsubs($ncomp);
  
  return $ncomp;

}


=back

=head1 REQUIREMENTS

Currently this module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)
    

=cut

 
1;
