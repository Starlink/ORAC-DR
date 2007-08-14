package ORAC::Xorac;

# ---------------------------------------------------------------------------

#+ 
#  Name:
#    ORAC::Xorac

#  Purposes:
#    Routines called from the Xoracdr launcher GUI

#  Language:
#    Perl module

#  Description:
#    This module contains the routines called from Xoracdr and handles 
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

use 5.006;
use strict;          # smack! Don't do it again!
use warnings;
use Carp;            # Transfer the blame to someone else

# Want to specify a font that is consistent with our
# resources. The easiest way to do this is simply to
# not specify a font. For testing want to get the resource
our $FONT = 'fixed';

# P O D  D O C U M E N T A T I O N ------------------------------------------

=head1 NAME

ORAC::Xorac - routines called from the Xoracdr launcher GUI

=head1 SYNOPSIS

  use ORAC::Xorac

  xorac_update_status( $status_text, $percent );
  xorac_about( $xoracdr_version );
  xorac_pause( $parent );
  xorac_help ( $parnet, $file );
  xorac_log_window( $win_str, \$orac_prt );
  xorac_recipe_window( );
  xorac_calib( \%options );
  xorac_select_recipe(  );
  xorac_editor( $diectory, $recipe );x

=head1 DESCRIPTION

This module contains the routines called from Xoracdr and handles most of
the GUI functionality

=head1 REVISION

$Id$

=head1 AUTHORS

Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>,
Malcolm Currie E<lt>mjc@star.rl.ac.ukE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research Council.
Copyright 2007 Science and Technology Facilities Council.
All Rights Reserved.

=cut

# L O A D  M O D U L E S --------------------------------------------------- 

#
#  ORAC modules
#
use ORAC::Basic;                    # orac_exit_normally
use ORAC::Event;                    # Tk hash table
use ORAC::Print;
use ORAC::Constants qw/:status/;    # ORAC__ABORT ORAC__FATAL

#
# General modules
#
use Tk;
use Tk::TextANSIColor;
use Tk::ORAC::RecipeSelect;

#
# Routines for export
#
require Exporter;
use vars qw/$VERSION @EXPORT @ISA /;

@ISA = qw/Exporter/;
@EXPORT = qw/ xorac_update_progress
              xorac_setenv xorac_log_window xorac_recipe_window
              xorac_about xorac_pause xorac_help xorac_select_recipe
	      xorac_calib xorac_select_filelist xorac_editor /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# S U B R O U T I N E S -----------------------------------------------------

=head1 SUBROUTINES

The following subroutines are available:

=over 4

=cut

# xorac_update_progress() ---------------------------------------------------

=item B<xorac_update_progress>

This subroutine updates the Tk::ProgressBar widget on Xoracdr starup 

    xorac_update_progress( $status_message, $percent );

=cut

sub xorac_update_progress {

  croak 'Usage: xorac_update_progress( $string, $percent )'
    unless scalar(@_) == 2 ;

  # Read the argument list
  my ($status_text, $percent) = @_;
  
  my $Lab = ORAC::Event->query("Label");
  my $Bar = ORAC::Event->query("Progress");
   
  $Lab->configure(-text => "$status_text ...");
  $Bar->value($percent);
  ORAC::Event->update("Tk");
 
}

# xorac_about() ----------------------------------------------------------

=item B<xorac_about>

This subroutine handles the ORAC-DR About popup window.

=cut

sub xorac_about {

  croak 'Usage: xorac_about( $xoracdr_version )'
    unless scalar(@_) == 1 ;

  my ( $xoracdr_version ) = @_;
  
  # top level frame
  my $top_level = ORAC::Event->query("Tk")->Toplevel();
  $top_level->title("About ORAC-DR");
  $top_level->positionfrom("user");
  $top_level->geometry("+80+80");  
  $top_level->configure( -cursor => "tcross" );

  # about frame
  my $about_frame = $top_level->Frame( -relief      => 'flat',
                                       -borderwidth => 10 );
  $about_frame->grid( -column => 0, -row => 0, -sticky => 'nsew' );

  # logo
  my $orac_logo = $about_frame->Photo(
                                  -file=>"$ENV{ORAC_DIR}/images/orac_logo.gif");
  my $image = $about_frame->Label( -image  => $orac_logo,
                                   -relief => 'flat',
		  		   -anchor => 'n');
  $image->grid( -column => 0, -row => 0, -sticky => 'nsew' );		 
  
  # text
  my $string;
  if ( defined $ENV{"ORAC_INSTRUMENT"} ) {
     $string = "\nXORAC-DR $xoracdr_version\nPerl Version $]\nTk version $Tk::VERSION\n\nInstrument: $ENV{'ORAC_INSTRUMENT'}\nSupport: $ENV{'ORAC_PERSON'}\@jach.hawaii.edu\nDocumentation: SUN/$ENV{'ORAC_SUN'}"
  } else {
     $string = "\nXORAC-DR $xoracdr_version\nPerl Version $]\nTk version $Tk::VERSION\n";
  }
    
  my $foot = $about_frame->Label( -textvariable    => \$string,
                                  -relief  => 'flat',
	  			  -font    => $FONT, 
				  -justify => 'center',
				  -anchor  => 'n',
				  -borderwidth => 5 );
  $foot->grid( -column => 1, -row => 0, -sticky => 'nsew' );		 

  # credits
  my $credits = $about_frame->Label( -text  => "\nFrossie Economou, Tim Jenness and Alasdair Allan\nCopyright (C) 1998-2001 Particle Physics and Astronomy Research Council.",
                                  -relief  => 'flat',
	  			  -font    => $FONT, 
				  -justify => 'center',
				  -anchor  => 'n',
				  -borderwidth => 5 );
  $credits->grid( -column => 0, -row => 1, -columnspan => 2, -sticky => 'nsew');	
  # license
  my $gpl = $about_frame->Label( -text => "\nThis program is free software; you can redistribute it and/or modify it under the\nterms of the GNU General Public License as published by the Free Software\nFoundation; either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful,but WITHOUT ANY\nWARRANTY; without even the implied warranty of MERCHANTABILITY or\nFITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License\nfor more details.\n\nYou should have received a copy of the GNU General Public License along with\n this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place,\n Suite 330, Boston, MA  02111-1307, USA",
                                 -relief  => 'flat',
	  			  -font    => $FONT, 
				  -justify => 'left',
				  -anchor  => 'n',
				  -borderwidth => 5 );
  $gpl->grid( -column => 0, -row => 2, -columnspan => 2, -sticky => 'nsew');	  

  # close button
  my $close_button = $top_level->Button( -text    => "Close",
                                         -font    => $FONT,
					 -activeforeground => 'white',
                                         -activebackground => 'blue',
                                         -command => 
					    sub { $top_level->destroy } );
  $close_button->grid( -column => 0, -row => 3, -sticky => 'e' );
  
}

# xorac_setenv() -----------------------------------------------------------

=item B<xorac_setenv>

This routine handles the Environment Variables setup pop-up window

=cut

sub xorac_setenv {

  croak 'Usage: xorac_setenv( $recipe_menu )'
    unless scalar(@_) == 1 ;
  
  my ($recipe_menu) = @_;
  
  # top level frame
  my $top_level = ORAC::Event->query("Tk")->Toplevel();
  $top_level->title("Set Environment Variables");
  $top_level->positionfrom("user");
  $top_level->geometry("+80+80");
  $top_level->configure( -cursor => "tcross" );

  # ORAC_DATA_ROOT entry field
  my $orac_data_root_label = $top_level->Label( 
                                        -text    => 'Data root directory',
                                        -relief  => 'groove',
				        -font    => $FONT,
				        -justify => 'left',
				        -anchor  => 'w');
  $orac_data_root_label->grid( -column => 0, -row => 0 , -sticky => 'ew');	

  my $orac_data_root_entry = $top_level->Entry( 
                                 -exportselection     => 1,
                                 -font                => $FONT,
				 -selectbackground    => 'blue',
				 -selectforeground    => 'white',
				 -justify             => 'left',
				 -textvariable        =>\$ENV{"ORAC_DATA_ROOT"},
				 -width               => 30 );
  $orac_data_root_entry->grid( -column => 1, -row => 0, -sticky => 'ew' );

  # ORAC_CAL_ROOT entry field
  my $orac_cal_root_label = $top_level->Label( 
                                       -text    => 'Calibration root directory',
                                        -relief  => 'groove',
				        -font    => $FONT,
				        -justify => 'left',
				        -anchor  => 'w');
  $orac_cal_root_label->grid( -column => 0, -row => 1 , -sticky => 'ew');	

  my $orac_cal_root_entry = $top_level->Entry( 
                                 -exportselection     => 1,
                                 -font                => $FONT,
				 -selectbackground    => 'blue',
				 -selectforeground    => 'white',
				 -justify             => 'left',
				 -textvariable        =>\$ENV{"ORAC_CAL_ROOT"},
				 -width               => 30 );
  $orac_cal_root_entry->grid( -column => 1, -row => 1, -sticky => 'ew' );

  # ORAC_RECIPIE_DIR entry field
  my $orac_recipe_dir_label = $top_level->Label( 
                                        -text    => 'User recipes',
                                        -relief  => 'groove',
				        -font    => $FONT,
				        -justify => 'left',
				        -anchor  => 'w');
  $orac_recipe_dir_label->grid( -column => 0, -row => 2 , -sticky => 'ew');	

  my $orac_recipe_dir_entry = $top_level->Entry( 
                                 -exportselection     => 1,
                                 -font                => $FONT,
				 -selectbackground    => 'blue',
				 -selectforeground    => 'white',
				 -justify             => 'left',
				 -textvariable      =>\$ENV{"ORAC_RECIPE_DIR"},
				 -width               => 30 );
  $orac_recipe_dir_entry->grid( -column => 1, -row => 2, -sticky => 'ew' );

  # ORAC_PRIMITIVE_DIR entry field
  my $orac_primitive_dir_label = $top_level->Label( 
                                        -text    => 'User primitives',
                                        -relief  => 'groove',
				        -font    => $FONT,
				        -justify => 'left',
				        -anchor  => 'w');
  $orac_primitive_dir_label->grid( -column => 0, -row => 3 , -sticky => 'ew');	

  my $orac_primitive_dir_entry = $top_level->Entry( 
                                 -exportselection     => 1,
                                 -font                => $FONT,
				 -selectbackground    => 'blue',
				 -selectforeground    => 'white',
				 -justify             => 'left',
				 -textvariable   =>\$ENV{"ORAC_PRIMITIVE_DIR"},
				 -width               => 30 );
  $orac_primitive_dir_entry->grid( -column => 1, -row => 3, -sticky => 'ew' );

  # ORAC_DATA_in entry field
  my $orac_data_in_label = $top_level->Label( 
                                        -text    => 'Input data',
                                        -relief  => 'groove',
				        -font    => $FONT,
				        -justify => 'left',
				        -anchor  => 'w');
  $orac_data_in_label->grid( -column => 0, -row => 4, -sticky => 'ew');	

  my $orac_data_in_entry = $top_level->Entry( 
                                 -exportselection     => 1,
                                 -font                => $FONT,
				 -selectbackground    => 'blue',
				 -selectforeground    => 'white',
				 -justify             => 'left',
				 -textvariable      =>\$ENV{"ORAC_DATA_IN"},
				 -width               => 30 );
  $orac_data_in_entry->grid( -column => 1, -row => 4, -sticky => 'ew' );

  # ORAC_DATA_OUT entry field
  my $orac_data_out_label = $top_level->Label( 
                                        -text    => 'Output data',
                                        -relief  => 'groove',
				        -font    => $FONT,
				        -justify => 'left',
				        -anchor  => 'w');
  $orac_data_out_label->grid( -column => 0, -row => 5, -sticky => 'ew');	

  my $orac_data_out_entry = $top_level->Entry( 
                                 -exportselection     => 1,
                                 -font                => $FONT,
				 -selectbackground    => 'blue',
				 -selectforeground    => 'white',
				 -justify             => 'left',
				 -textvariable      =>\$ENV{"ORAC_DATA_OUT"},
				 -width               => 30 );
  $orac_data_out_entry->grid( -column => 1, -row => 5, -sticky => 'ew' );

  # ORAC_DATA_CAL entry field
  my $orac_data_cal_label = $top_level->Label( 
                                        -text    => 'Instrument calibration',
                                        -relief  => 'groove',
				        -font    => $FONT,
				        -justify => 'left',
				        -anchor  => 'w');
  $orac_data_cal_label->grid( -column => 0, -row => 6, -sticky => 'ew');	

  my $orac_data_cal_entry = $top_level->Entry( 
                                 -exportselection     => 1,
                                 -font                => $FONT,
				 -selectbackground    => 'blue',
				 -selectforeground    => 'white',
				 -justify             => 'left',
				 -textvariable      =>\$ENV{"ORAC_DATA_CAL"},
				 -width               => 30 );
  $orac_data_cal_entry->grid( -column => 1, -row => 6, -sticky => 'ew' );
  
  # close button
  my $close_button = $top_level->Button( 
             -text    => "Close",
             -font    => $FONT,
	     -activeforeground => 'white',
	     -activebackground => 'blue',
	     -command => 
	     sub { 
	            	if( defined $ENV{"ORAC_RECIPE_DIR"} )
			{
	                   # check recipe directory exits, warn if it doesn't
		           # and disable recipe edit menu item
	                   unless (-d $ENV{"ORAC_RECIPE_DIR"}) { 
		               $recipe_menu->
			         entryconfigure(4, -state => 'disabled');
		               $recipe_menu->
			         entryconfigure(3, -state => 'disabled');
		           }
	                }
			
	                # if we have an instrument and a user recipe
			# directory we can edit recipes
	                if( defined $ENV{"ORAC_RECIPE_DIR"} &&
			    defined $ENV{"ORAC_INSTRUMENT"} ) {
                              $recipe_menu->
			         entryconfigure(4, -state => 'normal');
		              $recipe_menu->
			         entryconfigure(3, -state => 'normal');} 
			
			# So long and thanks for all the fish 
			$top_level->destroy; 
	         } );
  $close_button->grid( -column => 1, -row => 8, -sticky => 'e' );
  
 
}

# xorac_log_window() ------------------------------------------------------

=item B<xorac_log_window>

This subroutine sets up the ORAC-DR Tk log window used by both oracdr
and Xoracdr. The routine takes a text string specifying the identity
of the Tk device used for the log window (usually either "Tk" for the
MainWindow or "TL" for a TopLevel widget) and a pointer to the current
ORAC::Print object

  my ( $ORAC_MESSAGE, $TEXT1, $TEXT2, $TEXT3 ) = 
          xorac_log_window( $win_str, \$orac_prt );

returns references to the packed Tk variabe $ORAC_MESSAGE, and references
to the output, warning and error file handles.

=cut

sub xorac_log_window {

  croak 'Usage: xorac_log_window( $win_str, \$orac_prt )'
    unless scalar(@_) == 2;

  my ( $win_str, $orac_prt ) = @_;
  my ($msg1, $lab1, $textw1, $textw2, $textw3, $lab2);
  
  # Get the Window ID
  my $MW = ORAC::Event->query($win_str);
  $MW->configure( -cursor => "tcross" );

  $MW->bind("<Destroy>", [ sub { 
	          $$orac_prt->outhdl(\*STDOUT);
                  $$orac_prt->warhdl(\*STDOUT);
                  $$orac_prt->errhdl(\*STDERR);			       
	          record ORAC::Error::UserAbort( "Destroy from Log Window",
		                                 ORAC__ABORT );

	          # destroy the Tk widget
		  ORAC::Event->destroy($win_str);
		  ORAC::Event->unregister($win_str);

		  } ] );

   # New frame for the top messages
   my $frame = $MW->Frame->pack(-padx => 0, -pady => 5);
        
   # Create easy exit button
   $frame->Button( -text=>'Exit ORAC-DR',
	           -font=>$FONT,
                   -activeforeground => 'white',
                   -activebackground => 'blue',
		   -command => sub {
			
		        # Need to remove the tie - just use STDOUT and STDERR
		        $$orac_prt->outhdl(\*STDOUT);
                        $$orac_prt->warhdl(\*STDOUT);
                        $$orac_prt->errhdl(\*STDERR);
			
			# store an error to be flushed on the next update
		        record ORAC::Error::UserAbort( "Exited from log window",
			                               ORAC__ABORT ); 
			
			# destroy the Tk widget
			ORAC::Event->destroy($win_str);
			ORAC::Event->unregister($win_str);
			
		        })->pack(-side => "left");
			
   # Create a pause button
   $frame->Button( -text=>'Pause ORAC-DR',
	           -font=>$FONT,
                   -activeforeground => 'white',
                   -activebackground => 'blue',
		   -command => sub { 
		                       xorac_pause ( $MW ); 
		                   } )->pack(-side => "left");
			 		 
   # ORAC_PRINT messages
   my $ORAC_MESSAGE = 'ORAC-DR reducing observation --';
   $msg1   = $frame->
         Label(-width=>60,
	       -textvariable=>\$ORAC_MESSAGE,
	       -font=>$FONT)->pack(-side => "left");

   $textw1 = $MW->Scrolled('TextANSIColor',
	  		        -scrollbars=>'w',
		  	        -background=>'#555555',
			        -foreground=>'white',
			        -height => 30,
			        -width  => 90,
				-font    => $FONT
			   )->pack;
   $textw1->tagConfigure('ANSIfgmagenta', -foreground => '#ccccff');
   $textw1->tagConfigure('ANSIfgblue', -foreground => '#33ff33');
   $textw1->insert('end',"ORAC-DR status log\n");
   tie *TEXT1,  "Tk::TextANSIColor", $textw1;

   # ORAC_WARN messages
   $lab2   = $MW->Label(-text=>'Warnings',-font=>$FONT)->pack;
   $textw2 = $MW->Scrolled('TextANSIColor',
	  		        -scrollbars=>'w',
			        -background=>'#555555',
			        -foreground=>'white',
			        -height => 5,
			        -width  => 90,
				-font    => $FONT
			   )->pack;
   $textw2->insert('end',"ORAC-DR warning messages\n");
   tie *TEXT2,  "Tk::TextANSIColor", $textw2;

   # ORAC Error messages
   $lab1   = $MW->Label(-text=>'Errors',-font=>$FONT)->pack;
   $textw3 = $MW->Scrolled('TextANSIColor',
			        -scrollbars=>'w',
			        -background=>'#555555',
			        -foreground=>'white',
			        -height => 5,
			        -width  => 90,
				-font    => $FONT
			   )->pack;
    $textw3->insert('end',"ORAC-DR error messages\n");
    $textw3->tagConfigure('ANSIfgred', -foreground => '#ffcccc');
    tie *TEXT3,  "Tk::TextANSIColor", $textw3;

    # Routine returns references to packed Tk variable and
    # references to output, warning and error file handles
    return ( \$ORAC_MESSAGE, \*TEXT1, \*TEXT2, \*TEXT3 );

}

# xorac_recipe_window() ---------------------------------------------------

=item B<xorac_recipe_window>

This subroutine sets up a Tk window used to display the progress of the
current recipe. The routine takes a text string specifying the identity
of the Tk device used for the log window (usually either "Tk" for the
MainWindow or "TL" for a TopLevel widget) 

  my ( $PRIMITIVE_LIST, $CURRENT_PRIMITIVE ) = 
          xorac_log_window( $win_str, $CURRENT_RECIPE );

returns references to the packed Tk array variabe $PRIMITIVE_LIST and 
$CURRENT_PRIMITIVE.

=cut

sub xorac_recipe_window {

  croak 'Usage: xorac_recipe_window( $win_str, $CURRENT_RECIPE )'
    unless scalar(@_) == 2;

  my ( $win_str, $CURRENT_RECIPE ) = @_;

  use ORAC::Inst::Defn qw/ orac_determine_recipe_search_path /;
     
  # Create new toplevel window
  my $top_level = ORAC::Event->query($win_str)->Toplevel();
  $top_level->title("Xoracdr Recipe Window");
  $top_level->iconname("Recipe Window");
  $top_level->geometry("+500+15");                  
  
  # label
  my $label = $top_level->Label( -textvariable    => $CURRENT_RECIPE,
			         -relief  => 'flat',
	  	                 -font    => $FONT, 
		                 -justify => 'left',
			         -foreground =>'blue',
			         -anchor  => 'w',
		                 -borderwidth => 5 );
  $label->grid( -column => 0 ,-row => 0, -columnspan => 2, -sticky => 'nsew' );		 
  # listbox frame
  my $lbox_frame = $top_level->Frame(  -relief      => 'flat',
                                       -borderwidth => 10 );
  $lbox_frame->grid( -column => 0, -row => 1, -sticky => 'nsew' );
  
  # listbox
  my ( @PRIMITIVE_LIST, $CURRENT_PRIMITIVE );

  # scrolled listbox
  my $scrollbar = $lbox_frame->Scrollbar();
  		   
  my $lbox = $lbox_frame->Listbox(-borderwidth        => 1,
                                 -selectbackground    => 'blue',
			         -selectforeground    => 'white',
		  	         -background          => '#555555',
			         -foreground          => 'white',
			         -selectmode          => 'single',
				 -font                => $FONT,
				 -height              => 15,
				 -width               => 65,
				 -yscrollcommand      => ['set'=>$scrollbar]);

  $scrollbar->configure(-command=>['yview'=>$lbox]);

  tie @PRIMITIVE_LIST, "Tk::Listbox", $lbox;
  tie $CURRENT_PRIMITIVE, "Tk::Listbox", $lbox;
  
  # pack the listbox frame, pack scrollbar first!
  $scrollbar->grid( -column => 1, -row => 0, -sticky => 'nsew' );
  $lbox->grid( -column => 0, -row => 0 , -sticky => 'nsew');

  # about frame
  my $button_frame = $top_level->Frame( -relief      => 'flat',
                                        -borderwidth => 2 );
  $button_frame->grid( -column => 0, -row => 2, -sticky => 'e' );
                      
		      
  # edit recipe button, not for public consumption perhaps?
  my $edit_button = $button_frame->Button( -text           => 'Current Recipe ',
                                           -font             => $FONT,
                                           -activeforeground => 'white',
                                           -activebackground => 'blue',
  					   -command => 
	    sub {       # this callback will push the first occurance of the
	                # recipe in the directory search path to the editor
			# since we got this far we can assume the recipe
			# must exist somewhere in the users recipe path
			unless ( ORAC::Event->query("RE") ) { 
			  my @recipe = split /: /, $$CURRENT_RECIPE;     
			  my @dir_list =  orac_determine_recipe_search_path(
			                             $ENV{"ORAC_INSTRUMENT"} );
		          unshift ( @dir_list, $ENV{"ORAC_RECIPE_DIR"} ) 
                               if defined $ENV{"ORAC_RECIPE_DIR"};
                          for ( my $i = 0; $i < scalar(@dir_list) ; $i++ ) {
			    my $filename = $dir_list[$i] . "/" . $recipe[1];
			    if (-e $filename ) { 
		              xorac_editor( $dir_list[$i], $recipe[1])
			           if defined $recipe[1];
			      last;      
		            }
			  }
			}  
		  } );
  $edit_button->grid( -column => 0 ,-row => 0, -sticky => 'e' );		           
  # Cancel button
  my $cancel_button = $button_frame->Button( 
                               -text=>'Close',
	                       -font=>$FONT,	
			       -activeforeground => 'white',
                               -activebackground => 'blue',
	 	               -command => sub { untie @PRIMITIVE_LIST;
			                         undef @PRIMITIVE_LIST;
						 untie $CURRENT_PRIMITIVE;
						 undef $CURRENT_PRIMITIVE;
			                         $top_level->destroy; } );
  $cancel_button->grid( -column => 1 ,-row => 0, -sticky => 'e' );	

  $top_level->bind("<Destroy>", [ sub {  untie @PRIMITIVE_LIST;
                                         undef @PRIMITIVE_LIST;
					 untie $CURRENT_PRIMITIVE;
					 undef $CURRENT_PRIMITIVE; } ] );
  
  return ( \@PRIMITIVE_LIST, \$CURRENT_PRIMITIVE );
}  

# xorac_pause() ----------------------------------------------------------

=item B<xorac_pause>

This subroutine puts up a pause pop up window and halts further processing
until the window is closed by the user

=cut

sub xorac_pause {

  croak 'Usage: xorac_pause( $parent )'
    unless scalar(@_) == 1 ;
  
  # Parent widget
  my ( $parent ) = @_;
  
  # create pop-up widget
  my $popup = $parent->Toplevel();
  $popup->title("Paused");
  $popup->positionfrom("user");
  $popup->geometry("+90+90");
  $popup->configure( -cursor => "tcross" );
                 
  # label
  my $label = $popup->Label( -text    => "Processing paused",
			     -relief  => 'flat',
	  	             -font    => $FONT, 
		             -justify => 'center',
			     -anchor  => 'n',
		             -borderwidth => 5 );
  $label->grid( -column => 0 ,-row => 0, -sticky => 'nsew' );		           
  # button
  my $button = $popup->Button( -text=>'Resume',
	                       -font=>$FONT,	
			       -activeforeground => 'white',
                               -activebackground => 'blue',
	 	               -command => sub { $popup->destroy; } );
  $button->grid( -column => 0 ,-row => 1, -sticky => 'ns' );	
  
  # grab the local focus, might be a good idea?
  # $popup->grab();

  # Pause until widget is destroyed
  $popup->waitWindow();

}

# xorac_help() -------------------------------------------------------------

=item B<xorac_help>

This subroutine puts up a Tk::Pod widget 

=cut

sub xorac_help {

  croak 'Usage: xorac_help( $parent, $directory, $file )'
    unless scalar(@_) == 3 ;

  # Parent widget
  my ( $parent, $directory, $file ) = @_;

  eval "use Tk::Pod";
  if ( $@ ) { return; }
  
  # change working directories, this is a lousy kludge
  my $working_dir = $ENV{"PWD"};
  chdir ( $directory );
  
  # add directory to search path
  Tk::Pod->Dir( [ $directory ] );

  # create pop-up widget
  my $pod = $parent->Pod( -file => $file );

  # grab the local focus, because I'm using a lousy kludge to
  # change the current working directory so we can't let the
  # user play with the top level GUI or his output data might
  # end up in a wierd place. I think I want to fix this at some
  # point, its a really icky lousy kludge.
  $pod->grab();
  
  # Pause until widget is destroyed, due to kludge
  $pod->waitWindow();  

  # change back to working directory, due to kludge
  chdir ( $working_dir );
}
 
# xorac_select_recipe() ---------------------------------------------------

=item B<xorac_select_recipe>

This subroutine pops up a file selector to selected a recipe from the
current recipe search path.

=cut

sub xorac_select_recipe {

  croak 'Usage: xorac_select_recipe( )'
    unless scalar(@_) == 0 ;
   
  my ( $edit, $options ) = @_;
    
  my $instrument;
  
  # check we have an instrument
  if (defined $ENV{"ORAC_INSTRUMENT"} ) {
     $instrument = $ENV{"ORAC_INSTRUMENT"};
  } else {
     # this error should never occur
     orac_err(" ORAC_INSTRUMENT not defined\n"); 
     throw ORAC::Error::FatalError("ORAC_INSTRUMENT variable not set",
                                   ORAC__FATAL);
  }   
  
  # check we have a recipe directory
  if (exists $ENV{"ORAC_RECIPE_DIR"}) 
  {
     unless (-d $ENV{"ORAC_RECIPE_DIR"}) 
     {
     orac_err(" ORAC_RECIPE_DIR directory ($ENV{ORAC_RECIPE_DIR}) does not exist.\n");
     throw ORAC::Error::FatalError("ORAC_RECIPE_DIR does not exist",
                                   ORAC__FATAL);
     }
  
  } 
  else 
  {
     orac_err(" ORAC_RECIPE_DIR environment variable not set.\n");
     throw ORAC::Error::FatalError("ORAC_RECIPE_DIR variable not set",
                                   ORAC__FATAL);   
  }
  
  # top level frame
  my $MW = ORAC::Event->query("Tk");

  # Get the directory and filename from the user
  my $top_level = $MW->ORACRecipeSelect( -instrument => $instrument );
  $top_level->title("Select Recipe");
  $top_level->positionfrom("user");
  $top_level->geometry("+80+80");  
  $top_level->configure( -cursor => "tcross" );
    
  my ($directory, $filename ) = $top_level->Show;
   
  return ($directory, $filename);
		               
}

# xorac_editor() -----------------------------------------------------------

=item B<xorac_editor>

This subroutine pops a text widget to allow you to edit an recipe.

=cut

sub xorac_editor {

  croak 'Usage: xorac_select_recipe($directory, $recipe)'
    unless scalar(@_) == 2;
  
  my ( $directory, $recipe ) = @_;

  # open the recipe
  my $filename = $directory . "/" . $recipe;
  open ( FH, $filename ) || throw ORAC::Error::FatalError(
                              "Could not open $filename", ORAC__FATAL);

  # top level frame
  my $top_level = ORAC::Event->query("Tk")->Toplevel();
  ORAC::Event->register("RE"=>$top_level);
  $top_level->title("Recipe Editor");
  $top_level->positionfrom("user");
  $top_level->geometry("+80+80");  
  $top_level->configure( -cursor => "tcross" );

  # top label
  my $label_text = "Editing recipe: " . $recipe;
  my $label1 = $top_level->Label( -textvariable => \$label_text,
			          -relief       => 'flat',
	  	                  -font         => $FONT, 
		                  -justify      => 'left',
				  -foreground   => 'blue',
			          -anchor       => 'w',
		                  -borderwidth  => 5 );
  $label1->grid( -column => 0, -row => 0, -sticky => 'nsew' );		   
          
  # text widget	
  my $text = $top_level -> Scrolled("Text",
                                    -font => $FONT,
                                    -background          => '#555555',
			            -foreground          => 'white',	
				    -scrollbars => 'e');
	       
  # label frame
  my $label_frame = $top_level->Frame( -relief      => 'flat',
                                       -borderwidth => 2 );
    
  # 1st label
  my $in_str = "Loaded recipe: " . $directory . "/";
  my $label2 = $label_frame->Label( -textvariable    => \$in_str,
			         -relief  => 'flat',
	  	                 -font    => $FONT, 
		                 -justify => 'left',
			         -anchor  => 'w',
				 -foreground => 'blue',
		                 -borderwidth => 0 );
  $label2->grid( -column => 0, -row => 0, -sticky => 'nsw' );		           
  # 2nd label
  my $out_str = "Saving recipe: ". $ENV{"ORAC_RECIPE_DIR"} . "/";
  my $label3 = $label_frame->Label( -textvariable    => \$out_str,
			         -relief  => 'flat',
	  	                 -font    => $FONT, 
		                 -justify => 'left',
			         -anchor  => 'w',
				 -foreground => 'blue',
		                 -borderwidth => 0 );
  $label3->grid( -column => 0, -row => 1, -sticky => 'nsw' );

  # button frame
  my $button_frame = $top_level->Frame( -relief      => 'flat',
                                        -borderwidth => 2 );
    
  # Cancel button
  my $cancel_button = $button_frame->Button( -text=>'Close',
	                       -font=>$FONT,	
			       -activeforeground => 'white',
                               -activebackground => 'blue',
	 	               -command => sub { 
			            ORAC::Event->destroy("RE");
				    ORAC::Event->unregister("RE");  } );
  $cancel_button->grid( -column => 0 ,-row => 0, -sticky => 'e' );	
  
  # OK button
  my $save_button = $button_frame->Button( -text=>'Save Recipe',
	                       -font=>$FONT,	
			       -activeforeground => 'white',
                               -activebackground => 'blue',
			       -state => 'disabled' );

  $save_button->configure( -command => sub { 
                                if ( $save_button->cget( -state) eq 'active' ) 
                                {
                                    xorac_save_recipe( $recipe,\$text );
                                    $label_text = "Editing recipe: " . $recipe; 
                                } } );
  $save_button->grid( -column => 1 ,-row => 0, -sticky => 'we' );	

  # pack the frames
  $text->grid( -column => 0, -row => 1, -columnspan => 2, -sticky => 'nsew' );
  $button_frame->grid( -column => 1, -row => 2, -sticky => 'nse' );
  $label_frame->grid( -column => 0, -row => 2, -sticky => 'nsw' );

  # read the recipe 
  while ( <FH> ) {
     $text->insert('end', $_ );
  }
  close(FH);

  # bind any key input to add (modified) onto the recipe string
  $text->bind("<Key>", sub { 
                 unless ( $label_text =~ "modified" ) {
                    $save_button->configure(-state => 'normal' );
		    $label_text = $label_text . " (modified)"; } } );
  
} 

# xorac_save_recipe

sub xorac_save_recipe {

  croak 'Usage: xorac_save_recipe($recipe, \$text)'
    unless scalar(@_) == 2;
  
  my ( $recipe, $text ) = @_;

  my $filename = $ENV{"ORAC_RECIPE_DIR"} . "/" . $recipe;  
  open ( FH, "+>$filename" ) || throw ORAC::Error::FatalError(
                              "Could not open $filename", ORAC__FATAL);
  my $custom = $$text->get('1.0','end');
  print FH $custom;
  close(FH);
   
}
 
# xorac_calib() -----------------------------------------------------------

=item B<xorac_calib>

This subroutine pops up the Xoracdr calibration override interface

  xorac_calib ( /%options )

and returns a reference to a hash for %options{"calib"} unlike oracdr which
puts a string into this variable.

This subroutine will recursively call itself to redraw the calibration popup 
if the user adds additional calibration items to the list. 

=cut

sub xorac_calib {

  croak 'Usage: xorac_calib( \%options )'
    unless scalar(@_) == 1;
  
  my ( $options ) = @_;

  use ORAC::Inst::Defn qw/ orac_determine_inst_classes /;

  # create pop-up widget
  my $popup = ORAC::Event->query("Tk")->Toplevel();
  $popup->title("User Calibration");
  $popup->positionfrom("user");
  $popup->geometry("+90+90");
  $popup->configure( -cursor => "tcross" );
  
  # Declare label str
  my $label_txt;
  if ( defined $ENV{"ORAC_INSTRUMENT"} ) { 
     $label_txt = "Instrument: $ENV{'ORAC_INSTRUMENT'}";
  } else {
     $label_txt = "Instrument: UNDEFINED"; 
  }
     
  my $instrument_label = $popup->Label( -textvariable    => \$label_txt,
			                -relief          => 'flat',
	  	                        -font            => $FONT, 
		                        -justify         => 'left',
			                -foreground      => 'blue',
			                -anchor          => 'w',
		                        -borderwidth     => 5 );
  $instrument_label->grid( -column => 0, -row => 0, 
                           -columnspan => 2, -sticky => 'nsew' );
                   
  # create the calibration hash
  my %calib;

  my ($frameclass, $groupclass, $calclass, $instclass) =
           orac_determine_inst_classes( $ENV{"ORAC_INSTRUMENT"} );  

  if ( defined %{${$options}{"calib"}} ) {
      foreach my $key (keys %{${$options}{"calib"}}) {
          %calib = ( %calib, $key => ${${$options}{"calib"}}{$key} ); }
      foreach ( $instclass->return_possible_calibrations ) {
          %calib = ( %calib, $_ => ${${$options}{"calib"}}{$_} ); }
  } elsif ( defined $ENV{"ORAC_INSTRUMENT"} ) {
      foreach ( $instclass->return_possible_calibrations ) {
          %calib = ( %calib, $_ => ${${$options}{"calib"}}{$_} ); }
  } else {    
      foreach ( qw/ gains tausys badbols flat dark bias mask sky standard readnoise baseshift referenceoffset rotation / ) {
          %calib = ( %calib, $_ => ${${$options}{"calib"}}{$_} ); } }

  # Declare variables 
  my ( @labels, @entries );
  
  # fill the popup with junk
  foreach my $key (sort keys %calib) {
     push ( @labels, $popup->Label( -text    => $key,
			            -relief  => 'groove',
	  	                    -font    => $FONT, 
		                    -justify => 'left',
			            -anchor  => 'w',
				    -width   => 15,
		                    -borderwidth => 2 ) );
     push ( @entries, $popup->Entry( -exportselection     => 1,
                                     -font                => $FONT,
				     -selectbackground    => 'blue',
				     -selectforeground    => 'white',
				     -justify             => 'left',
				     -textvariable        =>\$calib{$key},
				     -width               => 30 ) );
  }
  
  # pack the widgets
  my $i;
  
  for ($i = 0; $i < scalar(@labels); $i++ )
  {
     $labels[$i]->grid( -column => 0, -row => $i+1, -sticky => 'ew' );
     $entries[$i]->grid( -column => 1, -row => $i+1, -sticky => 'ew' );
  }
 
  # additional calibration stuff
  #my ( $add_key, $add_val );
  
  #my $key_entry = $popup->Entry( -exportselection     => 1,
  #                               -font                => $FONT,
  #	                          -selectbackground    => 'blue',
  #	                          -selectforeground    => 'white',
  #		                  -justify             => 'left',
  #		                  -textvariable        =>\$add_key,
  # 		                  -width               => 15 );
  #$key_entry->grid( -column => 0, -row => $i+1, -sticky => 'ew' );
  #my $val_entry = $popup->Entry( -exportselection     => 1,
  #                               -font                => $FONT,
  #		                 -selectbackground    => 'blue',
  #		                 -selectforeground    => 'white',
  #			         -justify             => 'left',
  #			         -textvariable        =>\$add_val,
  #			         -width               => 15 );
  #$val_entry->grid( -column => 1, -row => $i+1, -sticky => 'ew' );

  # button frame
  my $button_frame = $popup->Frame( -relief      => 'flat',
                                    -borderwidth => 4 );
  $button_frame->grid( -column => 1, -row => $i+2, -sticky => 'nse' );

  # add button
  #my $add_button = $button_frame->Button( -text    => "Add",
  #                                        -font    => $FONT,
  #			                   -activeforeground => 'white',
  #                                        -activebackground => 'blue',
  #                                        -command => sub { 

   # push new key and value onto %calib and call recursively	
  #if ( $add_key ne "" && $add_val ne "" )
  #{
  #   %calib = ( %calib, $add_key => $add_val );	
  #   ${$options}{"calib"} = \%calib;
  #   $popup->destroy;
  #   xorac_calib($options);
  #} } );
  #
  #$add_button->grid( -column => 0, -row => 0, -sticky => 'e' );
 
  # cancel button
  my $cancel_button = $button_frame->Button( -text    => "Cancel",
                                            -font    => $FONT,
			                    -activeforeground => 'white',
                                            -activebackground => 'blue',
                                            -command => sub {
                                         $popup->destroy; } );
  $cancel_button->grid( -column => 0, -row => 0, -sticky => 'e' );
     
  # apply button
  my $apply_button = $button_frame->Button( -text    => "Apply",
                                            -font    => $FONT,
			                    -activeforeground => 'white',
                                            -activebackground => 'blue',
                                            -command => sub { 
				         ${$options}{"calib"} = \%calib;
                                         $popup->destroy; } );
  $apply_button->grid( -column => 1, -row => 0, -sticky => 'e' );     
}

# xorac_select_filelist() ----------------------------------------------

=item B<xorac_select_filelist>

This subroutine handles the file selector interface for the file loop
option.

=cut

sub xorac_select_filelist {

  croak 'Usage: xorac_select_filelist( /@obs )'
    unless scalar(@_) == 1 ;

  my ( $obs ) = @_;
    
  unless ( defined $ENV{"ORAC_DATA_IN"} ) {
     throw ORAC::Error::FatalError( " \$ENV{'ORAC_DATA_IN'} not defined ",
                                    ORAC__FATAL ); } 	

  unless ( opendir ( DIR, $ENV{"ORAC_DATA_IN"} ) ) {
     orac_err( " Directory ($ENV{'ORAC_DATA_IN'}) not found\n" );
     throw ORAC::Error::FatalError( " Directory $ENV{'ORAC_DATA_IN'} not found",
                                    ORAC__FATAL ); }	  

  # top level frame
  my $top_level = ORAC::Event->query("Tk")->Toplevel();
  $top_level->title("File Selection");
  $top_level->positionfrom("user");
  $top_level->geometry("+80+80");  
  $top_level->configure( -cursor => "tcross" );

  # label
  my $label_txt = "Current Directory: $ENV{'ORAC_DATA_IN'}";
  
  my $top_label = $top_level->Label( -textvariable    => \$label_txt,
			             -relief          => 'flat',
	  	                     -font            => $FONT, 
		                     -justify         => 'left',
			             -foreground      => 'blue',
			             -anchor          => 'w',
		                     -borderwidth     => 5 );
  $top_label->grid( -column => 0, -row => 0, -sticky => 'nsw' );
             
  # left frame
  my $left_frame = $top_level->Frame( -relief      => 'flat',
                                       -borderwidth => 10 );
  $left_frame->grid( -column => 0, -row => 1, -sticky => 'nsew' );

  # middle frame
  my $middle_frame = $top_level->Frame( -relief      => 'flat',
                                        -borderwidth => 10 );
  $middle_frame->grid( -column => 1, -row => 1, -sticky => 'nse' );
   
  # right frame
  my $right_frame = $top_level->Frame( -relief      => 'flat',
                                        -borderwidth => 10 );
  $right_frame->grid( -column => 2, -row => 1, -sticky => 'nse' );
 
  # listbox labels
  my $left_txt = "Un-selected Files";
  
  my $left_label = $left_frame->Label( -textvariable    => \$left_txt,
			             -relief          => 'flat',
	  	                     -font            => $FONT, 
		                     -justify         => 'left',
			             -foreground      => 'blue',
			             -anchor          => 'w',
		                     -borderwidth     => 2 );
  $left_label->grid( -column => 0, -row => 0, 
                     -columnspan => 2, -sticky => 'nsw' );
      
  my $right_txt = "Selected Files";
  
  my $right_label = $right_frame->Label( -textvariable    => \$right_txt,
			             -relief          => 'flat',
	  	                     -font            => $FONT, 
		                     -justify         => 'left',
			             -foreground      => 'blue',
			             -anchor          => 'w',
		                     -borderwidth     => 2 );
  $right_label->grid( -column => 0, -row => 0, 
                      -columnspan => 2, -sticky => 'nsw' );
     
  # contents for listbox
  my ( @contents, $selected_hash, %options );
  %options = ( ReturnType => "both" );
  	   
  @contents = ();
  @contents =  grep !/^\./, readdir *DIR;
  closedir DIR;
   
  # if we already have selected files remove them from the left hand box
  if ( defined @$obs ) {
     for ( my $i = 0; $i < scalar(@contents); $i++ ) {
        for( my $j = 0; $j < scalar(@$obs); $j++ ) {
           if( $contents[$i] eq $$obs[$j] ) {
	      splice @contents, $i, 1;
	   } 
	} 
     } 
  }
	      
  # scrolled listbox
  my $scrollbar = $left_frame->Scrollbar();  		   
  my $lbox = $left_frame->Listbox(-borderwidth         => 1,
                                  -selectbackground    => 'blue',
			          -selectforeground    => 'white',
			          -selectmode          => 'multiple',
				  -font                => $FONT,
				  -height              => 20,
				  -width               => 35,
				  -yscrollcommand      => ['set'=>$scrollbar]);
  $lbox->insert('end',sort @contents);

  $scrollbar->configure( -command => [ 'yview' => $lbox ]);

  tie $selected_hash, "Tk::Listbox", $lbox, %options; 
  tie @contents, "Tk::Listbox", $lbox;
   
  $scrollbar->grid( -column => 1, -row => 1, -sticky => 'nsew' );
  $lbox->grid( -column => 0, -row => 1, -sticky => 'nsew' );

  # selected files
  my ( @files, $remove_hash );
  
  # listbox widget
  my $scrollbar2 = $right_frame->Scrollbar();  		   
  my $lbox2 = $right_frame->Listbox(-borderwidth         => 1,
                                  -selectbackground    => 'blue',
			          -selectforeground    => 'white',
			          -selectmode          => 'multiple',
				  -font                => $FONT,
				  -height              => 20,
				  -width               => 35,
				  -yscrollcommand      => ['set'=>$scrollbar2]);

  $scrollbar2->configure( -command => [ 'yview' => $lbox2 ]);
  $lbox2->insert('end', @$obs);

  tie $remove_hash, "Tk::Listbox", $lbox2, %options;
  tie @files, "Tk::Listbox", $lbox2;
   
  $scrollbar2->grid( -column => 1, -row => 1, -sticky => 'nsew' );
  $lbox2->grid( -column => 0, -row => 1, -sticky => 'nsew' );

  # add and remove buttons

  # add button
  my $add_button = $middle_frame->Button( -text    => "Add",
                                            -font    => $FONT,
					    -activeforeground => 'white',
                                            -activebackground => 'blue',
                                            -command => sub { 
			# push selected files into contents of RH listbox
			my (@index, @element);
			foreach my $key ( keys %$selected_hash ) {
                           push ( @element, $$selected_hash{$key} );
			   push ( @index, $key ); }
			push( @files, @element ); 
		        my @deleted_indices = reverse sort { $a <=> $b } @index;
		        delete @contents[@deleted_indices]; 
			@contents = sort @contents; } );
  $add_button->grid( -column => 0, -row => 0, -sticky => 'we' );
    
  # remove button
  my $remove_button = $middle_frame->Button( -text    => "Remove",
                                         -font    => $FONT,
					 -activeforeground => 'white',
                                         -activebackground => 'blue',
                                         -command => sub {  
		        # push de-selected files into contents of LH listbox
			my (@index, @element);
			foreach my $key ( keys %$remove_hash ) {
                           push ( @element, $$remove_hash{$key} );
			   push ( @index, $key ); }
			push( @contents, @element ); 
			my @deleted_indices = reverse sort { $a <=> $b } @index;
		        delete @files[@deleted_indices]; 
			@contents = sort @contents; } );
  $remove_button->grid( -column => 0, -row => 1, -sticky => 'we' );

  # add and remove ALL files buttons

  # add all button
  my $addall_button = $middle_frame->Button( -text    => "Add all",
                                            -font    => $FONT,
					    -activeforeground => 'white',
                                            -activebackground => 'blue',
                                            -command => sub { 
			# push selected files into contents of RH listbox
			push( @files, @contents ); 
			@contents = (); } );
  $addall_button->grid( -column => 0, -row => 2, -sticky => 'we' );
    
  # remove button
  my $removeall_button = $middle_frame->Button( -text    => "Remove all",
                                         -font    => $FONT,
					 -activeforeground => 'white',
                                         -activebackground => 'blue',
                                         -command => sub {  
		        # push de-selected files into contents of LH listbox
			push( @contents, @files ); 
			@contents = sort @contents;
			@files = (); } );
  $removeall_button->grid( -column => 0, -row => 3, -sticky => 'we' );


  # cancel and okay buttons      
   
  # button frame
  my $button_frame = $top_level->Frame( -relief      => 'flat',
                                        -borderwidth => 10 );
  $button_frame->grid( -column => 2, -row => 2, -sticky => 'nse' );

  # cancel button
  my $cancel_button = $button_frame->Button( -text    => "Cancel",
                                            -font    => $FONT,
					    -activeforeground => 'white',
                                            -activebackground => 'blue',
                                            -command => sub {
					    untie @files;
					    untie @contents;
					    untie $remove_hash;
					    untie $selected_hash;
					    $top_level->destroy;
					  } );
  $cancel_button->grid( -column => 0, -row => 0, -sticky => 'e' );
    
  # ok button
  my $ok_button = $button_frame->Button( -text    => "OK",
                                         -font    => $FONT,
					 -activeforeground => 'white',
                                         -activebackground => 'blue',
                                         -command => sub { 
					    @$obs = @files;
					    untie @files;
					    untie @contents;
					    untie $remove_hash;
					    untie $selected_hash;
					    $top_level->destroy;
					  } );
  $ok_button->grid( -column => 1, -row => 0, -sticky => 'e' );
  
}


# ----------------------------------------------------------------------------

=back

=cut

1;
