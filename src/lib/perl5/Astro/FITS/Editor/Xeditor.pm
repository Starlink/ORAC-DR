package Astro::FITS::Editor::Xeditor;

# ---------------------------------------------------------------------------

#+ 
#  Name:
#    Astro::FITS::Editor::Xeditor

#  Purposes:
#    Routines called from the FITS Editor GUI

#  Language:
#    Perl module

#  Description:
#    This module contains the routines called from FITS Editor and handles 
#    most of the GUI functionality

#  Authors:
#    Alasdair Allan (aa@astro.ex.ac.uk)
#     {enter_new_authors_here}

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2001 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# ---------------------------------------------------------------------------

use strict;          # smack! Don't do it again!
use Carp;            # Transfer the blame to someone else

# P O D  D O C U M E N T A T I O N ------------------------------------------

=head1 NAME

Editor::Xeditor - routines called from the FITS Editor GUI

=head1 SYNOPSIS

  use Astro::FITS::Editor::Xeditor;
  
  editor_about( $editor_version );
  editor_open_header($file_select, $working_directory, $FILE_TYPE, $MW, $font);
  editor_display_header( $cards, $keyword_widget, $font );

=head1 DESCRIPTION

This module contains the routines called from FITS Editor and handles most of
the GUI functionality

=head1 REVISION

$Id$

=head1 AUTHORS

Alasdair Allan (aa@astro.ex.ac.uk),

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research Council.
All Rights Reserved.

=cut

# L O A D  M O D U L E S --------------------------------------------------- 

#
# General modules
#
use Tk;
use Astro::FITS::Header::CFITSIO; 
use Astro::FITS::Header::NDF 0.02 ();
use NDF;
use File::Spec;

#
# Routines for export
#
require Exporter;
use vars qw/$VERSION @EXPORT @ISA /;

@ISA = qw/Exporter/;
@EXPORT = qw/ editor_about editor_open_header editor_write_header
              editor_display_header /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# S U B R O U T I N E S -----------------------------------------------------

=head1 SUBROUTINES

The following subroutines are available:

=over 4

=cut

# editor_about() ----------------------------------------------------------

=item B<editor_about>

This subroutine handles the FITS Editor About popup window.

=cut

sub editor_about {

  croak 'Usage: editor_about( $editor_version, $MW, $font )'
    unless scalar(@_) == 3 ;

  my ( $editor_version, $MW, $font ) = @_;
  
  # top level frame
  my $top_level = $MW->Toplevel();
  $top_level->title("About FITS Editor");
  $top_level->positionfrom("user");
  $top_level->geometry("+80+80");  
  $top_level->configure( -cursor => "tcross" );

  # about frame
  my $about_frame = $top_level->Frame( -relief      => 'flat',
                                       -borderwidth => 10 );
  $about_frame->grid( -column => 0, -row => 0, -sticky => 'nsew' );

  # logo
  my $image_frame = $about_frame->Frame( -relief      => 'flat',
                                       -borderwidth => 10 ); 
				        
  my $orac_logo = $image_frame->Photo(
                     -file=>"$ENV{ORAC_DIR}/images/orac_logo.gif");
  my $starlink_logo = $image_frame->Photo(
                     -file=>"$ENV{ORAC_DIR}/images/starlink_logo.gif");				  
  my $image1 = $image_frame->Label( -image  => $orac_logo,
                                   -relief => 'flat',
		  		   -anchor => 'n');
  $image1->grid( -column => 0, -row => 0, -sticky => 'nsew' );		 
  
  my $image2 = $image_frame->Label( -image  => $starlink_logo,
                                   -relief => 'flat',
		  		   -anchor => 'n');
  $image2->grid( -column => 1, -row => 0, -sticky => 'nsew' );		
   
  $image_frame->grid( -column => 0, -row => 0, -sticky => 'nsew' );  
  # text
  my $string;
  $string = "\nFITS Editor $editor_version\nPerl Version $]\nTk version $Tk::VERSION\n";
    
  my $foot = $about_frame->Label( -textvariable    => \$string,
                                  -relief  => 'flat',
	  			  -font    => $font, 
				  -justify => 'center',
				  -anchor  => 'n',
				  -borderwidth => 5 );
  $foot->grid( -column => 1, -row => 0, -sticky => 'nsew' );		 

  # credits
  my $credits = $about_frame->Label( -text  => "\nAlasdair Allan (aa\@astro.ex.ac.uk)\nCopyright (C) 2001 Particle Physics and Astronomy Research Council.",
                                  -relief  => 'flat',
	  			  -font    => $font, 
				  -justify => 'center',
				  -anchor  => 'n',
				  -borderwidth => 5 );
  $credits->grid( -column => 0, -row => 1, -columnspan => 2, -sticky => 'nsew');	
  # license
  my $gpl = $about_frame->Label( -text => "\nThis program is free software; you can redistribute it and/or modify it under the\nterms of the GNU General Public License as published by the Free Software\nFoundation; either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful,but WITHOUT ANY\nWARRANTY; without even the implied warranty of MERCHANTABILITY or\nFITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License\nfor more details.\n\nYou should have received a copy of the GNU General Public License along with\n this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place,\n Suite 330, Boston, MA  02111-1307, USA",
                                 -relief  => 'flat',
	  			  -font    => $font, 
				  -justify => 'left',
				  -anchor  => 'n',
				  -borderwidth => 5 );
  $gpl->grid( -column => 0, -row => 2, -columnspan => 2, -sticky => 'nsew');	  

  # close button
  my $close_button = $top_level->Button( -text    => "Close",
                                         -font    => $font,
					 -activeforeground => 'white',
                                         -activebackground => 'blue',
                                         -command => 
					    sub { $top_level->destroy } );
  $close_button->grid( -column => 0, -row => 3, -sticky => 'e' );
  
}

# editor_open_header() -------------------------------------------------------

=item B<editor_open_header>

This subroutine creates a header object from the input file

=cut


sub editor_open_header {

  croak 'Usage: $header = editor_open_header($file_select, $working_directory, $FILE_TYPE, $MW, $font)'
    unless scalar(@_) == 5;

  my ( $file_select, $working_directory, $FILE_TYPE, $MW, $font ) = @_;
  
  # declare variables
  my ($file_type);  
  
  # decide whether it is an NDF or raw FITS file from extension
  if( $$file_select[0] =~ ".sdf" ) {
     # we must have an NDF file
     $file_type = "NDF"; $$FILE_TYPE = "File: NDF";  
  } elsif ( $$file_select[0] =~ ".fit" || $$file_select[0] =~ ".fits" ) {
     # we must have a FITS file
     $file_type = "FIT"; $$FILE_TYPE = "File: FIT"; 
  } elsif ( $$file_select[0] =~ ".raw" ) {
     # we must have an ARK file
     $file_type = "ARK"; $$FILE_TYPE = "File: ARK";
  } else {
     # unidentified
     $MW->Dialog(-title => 'Error',
   		 -text => "File $$file_select[0] is of an unknown file type.\n",
   	         -bitmap => 'error',
		 -font => $font)->Show;
     return;
  }
  
  # open file if it exists
  my $filename = File::Spec->catfile( $working_directory, $$file_select[0] );
  unless ( open ( FH, $filename ) )
  {
     $MW->Dialog( -title => 'Error',
   		  -text => "File $filename not found.\n",
   	          -bitmap => 'error',
		  -font => $font)->Show;
     return;
  }
  
  # declare variables
  my ( $header );
  
  # create appropriate header
  if ( $file_type eq "NDF" ) {

     eval {
        $header = new Astro::FITS::Header::NDF( File => $filename );
     };

     if ($@) {

        $MW->Dialog( -title => 'Error',
   		-text => "Error opening NDF: $@\n",
   	        -bitmap => 'error',
		-font => $font)->Show;
        return;
     }

  } elsif ( $file_type eq "FIT" ) {
     $header = new Astro::FITS::Header::CFITSIO( File => $filename );
  } else {
     $header = new Astro::FITS::Header::CFITSIO( File => $filename );     
  }
  if ( ! defined $header ) {

     $MW->Dialog( -title => 'Error',
   		  -text => "Error opening file $filename.\n",
   	          -bitmap => 'error',
		  -font => $font)->Show;
     return;
  }  
      
  return ( $header, $filename );
}

# editor_write_header() ------------------------------------------------------

=item B<editor_write_header>

This subroutine writes the modified header object back to the orginal file

=cut

# editor_display_header() ----------------------------------------------------

=item B<editor_display_header>

This subroutine handles populating the keyword frame.

=cut

sub editor_display_header {

  croak 'Usage: editor_display_header( $cards, $keyword_widget, $font )'
    unless scalar(@_) == 3;

  my ( $cards, $keyword_widget, $font ) = @_;

  # grab individual cards from the array of FITS::Header::Items
  my ( @header_keyword, @header_value, @header_comment, @header_type );
  for my $i ( 0 .. scalar(@$cards)-1 ) {
     $header_keyword[$i] = $$cards[$i]->keyword();
     $header_value[$i] = $$cards[$i]->value();
     $header_comment[$i] = $$cards[$i]->comment(); 
     $header_type[$i] = $$cards[$i]->type();
  }

  # declare variables 
  my ( @number, @key, @value, @comment, $blank );
	
  # create widgets, loop over the @cards array
  for my $i ( 0 .. $#header_keyword ) {
     push (@number, $keyword_widget->Label( -text    => $i,
	  		                      -relief  => 'flat',
	  	                              -font    => $font, 
		                              -justify => 'left',
			                      -anchor  => 'w',
				              -width   => 3,
		                              -borderwidth => 2 ) );
     push (@key, $keyword_widget->Label( -text    => $header_keyword[$i],
	  		                 -relief  => 'flat',
	  	                         -font    => $font, 
		                         -justify => 'left',
			                 -anchor  => 'w',
				         -width   => 15,
		                         -borderwidth => 2 ) );
     $number[$i]->grid( -column => 0, -row => $i+1, -sticky => 'ew' );
     $key[$i]->grid( -column => 1, -row => $i+1, -sticky => 'ew' );
     if( $header_type[$i] eq "COMMENT" ) {
        push ( @comment, $keyword_widget->Entry( 
	                                  -exportselection     => 1,
                                          -font                => $font,
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					 -textvariable => \$header_comment[$i],
				          -width               => 80 ) ); 	
       $comment[$i]->grid( -columnspan => 2, -column => 2, -row => $i+1,
	                    -sticky => 'ew' );          
     } elsif ( $header_type[$i] eq "END" ) {
         $blank = $keyword_widget->Label( -text    => " ",
	  		                      -relief  => 'groove',
	  	                              -font    => $font, 
		                              -justify => 'left',
			                      -anchor  => 'w',
				              -width   => 80,
		                              -borderwidth => 2 );
         $blank->grid( -columnspan => 2, -column => 2, -row => $i+1, 
                         -sticky => 'ew' ); 
     } else {
         $value[$i] = $keyword_widget->Entry( 
	                                  -exportselection     => 1,
                                          -font                => $font,
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					  -textvariable => \$header_value[$i],
				          -width               => 30 );
         push ( @comment, $keyword_widget->Entry( 
	                                  -exportselection     => 1,
                                          -font                => $font,
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					 -textvariable => \$header_comment[$i],
				          -width               => 50 ) ); 
         $value[$i]->grid( -column => 2, -row => $i+1, -sticky => 'ew' );
         $comment[$i]->grid( -column => 3, -row => $i+1, -sticky => 'ew' );
     }
  }     
  return (\@number, \@key, \@value, \@comment, \$blank, 
          \@header_value, \@header_comment );
}


1;
