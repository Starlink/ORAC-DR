package ORAC::Index;

=head1 NAME

ORAC::Index - perl routines for manipulating ORAC index files

=head1 SYNOPSIS

use ORAC::Index;


=head1 DESCRIPTION

This module provides subs for manipulating ORAC index files. ORAC
index files consist of whitespace seperated columns containing
information about a particular frame.

In the case of calibration index files, these may also contain rules
for determining the suitability of use for these frames. These consist
of code that is TRUE or FALSE depending on appropriate header values
of the object to be calibrated.

=cut


use Carp;
use strict;
use vars qw/$VERSION/;
use ORAC::Print;

$VERSION = '0.10';

=head1 PUBLIC METHODS

The following methods are available in this class.

=over 4

=item new

Create a new instance of an ORAC::Index object.

$Index = new ORAC::Index;

=cut

sub new {
  
  
  my $proto = shift;
  my $class = ref($proto) || $proto;
  
  my $index = {};			# Anon hash reference
  $index->{IndexRules} = {};		# ditto
  $index->{IndexEntries} = {};		# ditto
  
  $index->{IndexFile} = undef;
  $index->{IndexFileHandle} = undef;
  $index->{IndexRulesFile} = undef;
  
  bless($index, $class);
  
  if (@_) { $index->configure(@_)};
  
  
  return $index;
  
};

=item indexfile

Return (or set) the filename of the index file

$file = $Index->indexfile;

=cut


sub indexfile {
  my $self = shift;
  if (@_) {
    $self->{IndexFile} = shift; 
    $self->slurpindex;    
  };
  return $self->{IndexFile};
};


=item filehandle

Return (or set) the filehandle of the index file

$FILE = $Index->filehandle;

=cut


sub filehandle {
  my $self = shift;
  
  
  if (@_) {				# if Joe is trying to set this...
    my $handle = shift;
    
    
    if (UNIVERSAL::isa($handle,"IO")) {	# ... and it IS a file handle object...
      $self->{IndexFileHandle} = $handle; # ... do it..
    } else {				# ... otherwise barf
      carp "$handle is not a filehandle object: attempt to set ignored";
    };
    
  };
  return $self->{IndexFileHandle};
};


=item indexrulesfile

Return (or set) the filename of the rules file

=cut

sub indexrulesfile {
  my $self = shift;
  if (@_) {
    $self->{IndexRulesFile} = shift; 
    $self->slurprules;
  };
  return $self->{IndexRulesFile};
};

=item configure

Takes an index file and an rules file and sets up the index object

=cut

sub configure {
  my $self = shift;
  my ($file,$rules) = @_;
  $self->indexfile($file);
  $self->indexrulesfile($rules);
};

=item rulesref

Returns or sets the reference to the hash containing the rules

=cut

sub rulesref {
  my $self = shift;
  
  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{IndexRules} = $arg;
  }
  
  return $self->{IndexRules};
}

=item indexref

Returns or sets the reference to the hash containing the index

=cut

sub indexref {
  my $self = shift;
  
  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{IndexEntries} = $arg;
  }
  
  return $self->{IndexEntries};
}


=item slurprules

Sets up the index rules in the object. Croaks if it fails.

=cut

sub slurprules {
  
  my $self = shift;
  my $file = $self->indexrulesfile;
  
  my %rules = ();
  my $handle = new IO::File "< $file";
  
  
  if (defined $handle) {
    
    foreach my $line (<$handle>) {
      
      next if $line =~ /^\s*		#/;
      
      $line =~ s/^\s+//g;		# zap leading blanks
      my ($header,$rule)=split(/\s+/,$line,2);
      
      next unless defined $header;	# skip blank lines
      $rules{$header} = $rule;
      
    };
    
  } else {
    
    croak("Couldn't open rules file $file : $!");
    
  };
  
  $self->rulesref(\%rules);
  
};


=item slurpindex

Sets up the index data in the object. Croaks if it fails.

=cut

sub slurpindex {
  
  my $self = shift;
  my $file = $self->indexfile;
  return unless (-e $file);
  
  my %index = ();
  my $handle = new IO::File "< $file";
  
  
  if (defined $handle) {
    
    foreach my $line (<$handle>) {
      
      next if $line =~ /^\s*#/; 

      $line =~ s/^\s+//g;		# zap leading blanks
      my ($name,@data)=split(/\s+/,$line);
      
      next unless defined $name;	# skip blank lines
      $index{$name} = \@data;
      
    };
    
  } else {
    
    croak("Couldn't open rules index $file : $!");
    
  };
  
  $self->indexref(\%index);
  
};

=item writeindex

writes out the current state of the index object into the index file

=cut

sub writeindex {
  
  my $self=shift;
  my $file = $self->indexfile;
  
  my %index = %{$self->indexref};
  my $handle = new IO::File "> $file";
  
  
  if (defined $handle) {
    
    print $handle "#",join(" ",sort keys %{$self->rulesref}),"\n";
    
    foreach my $entry (sort keys %index) {
      print $handle $entry," ",join(" ",@{$index{$entry}}),"\n";      
    };
    
  } else {
    
    croak("Couldn't open index $file : $!");
    
  };
  
};

=item add 

adds an entry to an index

$index->add($name,$hashref)

=cut

sub add {
  
  my $self=shift;
  croak('Usage: add($name,$hashref)') unless (scalar(@_)==2);
  my ($name,$hashref) = @_;
  
  croak("Argument is not a hash") unless ref($hashref) eq "HASH";  
  
  my @entry = ();
  foreach my $key (sort keys %{$self->rulesref}) {
    if (exists $$hashref{$key}) {
      push (@entry,$$hashref{$key});
    } else {
      croak "Rules file specifies entry $key unknown to file header";
    };
  };
  $ {$self->indexref}{$name} = \@entry;
  $self->writeindex;
};

=item verify

verifies a frame against a (calibration) index entry

Returns undef (error), 0 (not suitable), or 1 (suitable)

=cut

sub verify {

  my $self=shift;
  # expect the name of the calibration file and the object header hash
  croak('Usage: verify($calibration,$hashref)') unless (scalar(@_)==2);
  
    my ($name,$hashref) = @_;

  croak("Argument is not a hash") unless ref($hashref) eq "HASH";  
  return 0 unless defined $name;

  unless (exists $ {$self->indexref}{$name}) {
    orac_err "$name is unknown to oracdr and may not be used as calibration\n";
    orac_err "Make sure it is reduced by oracdr\n";
    return 0;
  };

  # take local copy of the calibration data index entry
  my @calibdata = @{$ {$self->indexref}{$name}};
  # take local copy the rules
  my %rules = %{$self->rulesref};
  # take local copy of the object header hash
  my %Hdr = %$hashref;

  # check that number of rules match index entries
  unless ($#calibdata == (scalar(keys %rules) - 1)) {
    print '$#calibdata is ',$#calibdata,'(scalar(keys %rules) - 1)) is ',(scalar(keys %rules) - 1),"\n";
    orac_err "Something has gone seriously wrong with the index file\n";
    orac_err "You will need to regenerate it\n";
    return undef;
  };
  
  foreach my $key (sort keys %rules) {
    # remember, by design the index file data is already sorted by rule order
    my $calvalue = shift(@calibdata);	# value of nth index entry
    # ignore if there is no rule attached to the keyword
    next unless defined $rules{$key};

    my $ok = eval("'$calvalue' $rules{$key}");
    if ($@) {
      orac_err "Eval error - check the syntax in your rules file\n";
      orac_err "Error was: $@ \n";
      return undef;
    };
    unless ($ok) {
      print "\n-",$Hdr{$key},"-\n","-$calvalue-\n";
      orac_warn("$name not a suitable calibration: failed $key $rules{$key}\n");
      return 0;
    };
    
  };

  
  # if we have gotten to this stage, the calibration must be groovy
  return 1;
  
};

=item choosebydt

Chooses the optimal (nearest in time to an observation) calibration
frame from the index hash

=cut


sub choosebydt {

my $self=shift;

 my ($timekey,$hashref) = @_;

  croak("Argument is not a hash") unless ref($hashref) eq "HASH";  

  my %Hdr = %$hashref;

croak("Key $timekey unknown to orac - this should not happen\n") 
 unless exists $Hdr{$timekey};

my %index = %{$self->indexref};

my $pos = -1;

foreach my $key (sort keys %{$self->rulesref}) {
$pos++;
last if $key eq $timekey;
};

($pos < 0) && croak("Key $timekey not in rules - how can I be expected to work under these conditions?");

my %dthash = (); # this is the hash for the keys and the associated time differences
  foreach my $key (keys %index) {
   # calculate the absolute value of the time difference wrt to the object
   $dthash{$key} = abs($ {$index{$key}}[$pos]-$Hdr{$timekey});
  };
   
# sort index keys by value (delta-tee)
# as described by Economou (1997) TPJ 2 2 :-) :-)
my @timesorted = sort {$dthash{$a} <=> $dthash{$b}} keys %dthash;

foreach my $calibration (@timesorted) {

  my $ok = $self->verify($calibration,\%Hdr);

  return $calibration if ($ok);
};

# If we get to this point, we didn't find any suitable ones

croak("No suitable calibrations were found in index file. Sorry.");

};



=back

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)

=cut

1;
