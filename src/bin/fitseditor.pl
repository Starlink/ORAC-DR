#!/usr/bin/perl

# S T A R L I N K  D O C U M E N T I O N ------------------------------------

#+
#  Name:
#    fitseditor

#  Purposes:
#    X-Windows FITS header editor

#  Language:
#    Perl script

#  Invocation:
#    Invoked by ${ORAC_DIR}/etc/fitseditor_start.csh

#  Description:
#

#  Authors:
#    Alasdair Allan (aa@astro.ex.ac.uk)

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2001 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# ---------------------------------------------------------------------------

#use 5.006;

use strict;
use vars qw/$VERSION/;

# P O D  D O C U M E N T A T I O N ------------------------------------------

=head1 NAME

fitseditor - Manipulate FITS headers using a GUI

=head1 SYNOPSIS

   fitseditor [-vers]

=head1 DESCRIPTION

C<fitseditor> is an X Windows GUI that can be used to modify headers
of a FITS file or a Starlink NDF.


=head1 REVISION

$Id$

=head1 AUTHORS

Alasdair Allan (aa@astro.ex.ac.uk)

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research Council.
All Rights Reserved.

=cut

# H A N D L E  V E R S I O N -----------------------------------------------

#  Version number - do this before anything else so that we dont have to
#  wait for all the modules to load - very quick
BEGIN {
  $VERSION = sprintf "%d", q$Revision$ =~ /(\d+)/;

  #  Check for version number request - do this before real options handling
  foreach (@ARGV) {
    if (/^-vers/) {
      print " fitseditor: version $VERSION\n";
      print " Using PERL version: $]\n";
      exit;
    }
  }
}

# L O A D  M O D U L E S ----------------------------------------------------

#
#  ORAC modules
#
use lib $ENV{"ORAC_PERL5LIB"};     # Path to FITSEDITOR modules

#
#  Editor modules
#
use Astro::FITS::Editor::Xeditor;

#
#  General modules
#
use Pod::Usage;
use Getopt::Long;
use POSIX qw/:sys_wait_h/;
use Errno qw/EAGAIN/;
use Getopt::Long;
use File::Spec;

#
# Tk modules
#
use Tk;
require Tk::Menu;
require Tk::Pane;
require Tk::Dialog;
require Tk::FileDialog;

# C R E A T E  M A I N  W I N D O W -----------------------------------------

my $MW = MainWindow->new();
$MW->positionfrom("user");
$MW->geometry("+40+100");
$MW->title("FITS Editor $VERSION");
$MW->iconname("FITS Editor");
$MW->configure( -cursor => "tcross" );

# Declare status variable here so we can pass it to processing loop
my ( $CURRENT_STATUS, $CURRENT_DIRECTORY, $FILE_TYPE );

# Declare anonymous sub-routines (this is doing it wrong)
my ( $file_request, $read_file, $update_window,
     $rebuild_widgets, $commit_changes );

# Declare file path variables
my ( $working_directory, $old_directory, $file_select, @file_list );

# O P T I O N S   H A N D L I N G --------------------------------------------

my ( %opt, $font );
my $status = GetOptions("dir=s" => \$opt{"dir"},
                        "file=s" => \$opt{"file"},
			"fnt=s" => \$opt{"font"},
                        "pt=s"  => \$opt{"pt"});

# Current working directory
$working_directory = $opt{"dir"} if defined $opt{"dir"};

# Change font size
if ( defined $opt{"font"} ) { 
   $font = $opt{"font"};
} else { 
   $font = "Helvetica"; 
}

# Change font size
if ( defined $opt{"pt"} ) { 
   $font = "$font $opt{pt}";
} else { 
   $font = "$font 10"; 
}

# B U I L D  M E N U  B A R -------------------------------------------------

# Declare variables
my ( @menus );
my ( $file_menu, $options_menu, $help_menu );

# Frame for menu bar
my $menu_frame = $MW->Frame( -relief      =>'raised', 
                             -borderwidth => 1);

foreach ( qw/File Options Help/ )
{
   push (@menus, $menu_frame->Menubutton( -font => $font, -text => $_ ) );
}

# Help menu
$menus[2]->pack( -side => 'right' );
$help_menu = $menus[2]->Menu( -tearoff => 0, -font => $font );
$menus[2]->configure( -menu => $help_menu );

$menus[2]->menu()->add( "command", -label => "Help",
                        -command => sub { } );				
$menus[2]->menu()->add( "separator" );
$menus[2]->menu()->add( "command", -label => "About FITS Editor",
                        -command => [ \&editor_about, $VERSION, $MW, $font ] );

# No help at present
$menus[2]->menu()->entryconfigure(0, -state => 'disabled' );

# File menu
$menus[0]->pack( -side => 'left'); 
$file_menu = $menus[0]->Menu( -tearoff => 0, -font => $font );

$menus[0]->configure( -menu => $file_menu );

$menus[0]->menu()->add( "command", -label => "Open Directory",
                        -command => sub {  &$file_request; } );


$menus[0]->menu()->add( "command", -label => "Commit Changes",
                        -state => 'disabled',
                        -command => sub { &$commit_changes } );			
			
$menus[0]->menu()->add( "separator" );

$menus[0]->menu()->add( "command", -label => "Exit",
                        -command => sub { $MW->destroy(); } );

# Options menu
$menus[1]->pack( -side => 'left' );
$options_menu = $menus[1]->Menu( -tearoff => 0, -font => $font );

$menus[1]->configure( -menu => $options_menu );

$menus[1]->menu()->add( "separator" );
# Calls Editor::editor_prefs() to do set user preferences
$menus[1]->menu()->add( "command",
                        -label   => "Preferences", 
                        -command => sub { editor_prefs(); });

# Options menu unused at present
$menus[1]->configure( -state => 'disabled' );

# B U I L D   L A B E L -----------------------------------------------------

# Frame for top label
my $label_frame = $MW->Frame( -relief      =>'groove', 
                              -borderwidth => 1 );
			      
# Status label
my $top_label = $label_frame->Label( -textvariable => \$CURRENT_DIRECTORY,
                                         -font         => $font,
					 -foreground   => 'blue');
#$top_label->grid( -column => 0, -row => 0, -sticky => 'we' );
$top_label->pack( -side => 'left' );
$CURRENT_DIRECTORY = "Working directory: ";			        
		
my $directory_entry = $label_frame->Entry( -exportselection     => 1,
                            -font                => $font,
		            -selectbackground    => 'blue',
		            -selectforeground    => 'white',
			    -justify             => 'left',
			    -textvariable        => \$working_directory,
		            -width               => 25 );
#$directory_entry->grid( -column => 1, -row => 0, -sticky => 'w' );
$directory_entry->pack( -side => 'left' );

# Save changes button
my $save_button = $label_frame->Button( -text             => 'Commit Changes',
                                        -font             => $font,
                                        -activeforeground => 'white',
                                        -activebackground => 'blue',
					-state            => 'disabled',
					 );

#$save_button->grid( -column => 2, -row => 0, -sticky => 'e' );
$save_button->pack( -side => 'right' );

# M A I N   F R A M E -------------------------------------------------------

# Holding frame
my $main_frame = $MW->Frame( -relief      =>'flat', 
                             -borderwidth => 1 );

# Frame for keyword panel
my $right_frame = $main_frame->Frame( -relief      =>'flat', 
                              -borderwidth => 1 );
$right_frame->grid( -column => 2, -row => 0, -sticky => 'nsew');
				
# B U I L D   F I L E   P A N E L -------------------------------------------

			       
# Listbox for file selection
my $left_scrollbar = $main_frame->Scrollbar();
my $files = $main_frame->Listbox( -borderwidth         => 1,
                                  -selectbackground    => 'blue',
				  -selectforeground    => 'white',
				  -selectmode          => 'single',
				  -font                => $font,
				  -width               => 30,
				  -yscrollcommand => ['set'=>$left_scrollbar]);
			       	
$left_scrollbar->configure(-command=>['yview'=>$files]);
$left_scrollbar->grid( -column => 1, -row => 0, -sticky => 'nsew');

# Fill the listbox if we already have a working directory 
$files->insert('end', sort @file_list);
$files->grid( -column => 0, -row => 0, -sticky => 'nsew');

# Bind the 2nd mouse button to the Tk::Listbox and use the scan method
$main_frame->bind("Listbox", "<2>",['scan','mark',Ev('x'),Ev('y')]);
$main_frame->bind("Listbox", "<B2-Motion>",['scan','dragto',Ev('x'),Ev('y')]);

# Tie the Listbox to the @file_list array, note that this currently uses
# a locally modified copy of Tk::Listbox since by default the Listbox
# widget doesn't come with tied variables. 
tie @file_list, "Tk::Listbox", $files;

# Tie the Listbox to the $file_select scalar, note that this currently
# uses a locally modifed copy of Tk::Listbox since by default the Listbox
# widget doesn't come with tied variables.
tie $file_select, "Tk::Listbox", $files;
				       
# B U I L D   K E Y W O R D   P A N E L -------------------------------------

# Create scrollable widget frame using Tk::Pane
my $keyword_widget = $right_frame->Scrolled( "Pane", Name  => 'keyword_frame',
                                             -scrollbars => 'e',
			       	             -sticky     => 'nsew',
				             -gridded    => 'y',
					     -height     => 300,
					     -width      => 700,
					     -relief     => 'groove' );
$keyword_widget->Frame;
$keyword_widget->grid( -columnspan => 2,
                       -column => 0, -row => 0, -sticky => 'nsew' );

# A D D   K E  Y W O R D   P A N E L -----------------------------------------

# Add keyword panel, sub-panel of the right main panel
my $add_keyword_frame = $right_frame->Frame( -relief      => 'groove',
                                             -borderwidth => 1 );

$add_keyword_frame->grid( -column => 0, -row => 1, -sticky => 'nsew' );

# Declare variables
my ( $new_keyword, $new_value, $new_comment );

# Widgets and stuff
my $add_label = $add_keyword_frame->Label( -text => "New Header Card",
                                         -font         => $font );

my $keyword_entry = $add_keyword_frame->Entry( 
	                                  -exportselection     => 1,
                                          -font                => 'Fixed',
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					  -textvariable => \$new_keyword,
				          -width               => 8 );
my $value_entry = $add_keyword_frame->Entry( 
	                                  -exportselection     => 1,
                                          -font                => 'Fixed',
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					  -textvariable => \$new_value,
				          -width               => 20 );
my $comment_entry = $add_keyword_frame->Entry( 
	                                  -exportselection     => 1,
                                          -font                => 'Fixed',
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					  -textvariable => \$new_comment,
				          -width               => 40 );

my $add_button = $add_keyword_frame->Button(-text             => 'Add',
                                        -font             => $font,
                                        -activeforeground => 'white',
                                        -activebackground => 'blue',
					-state            => 'disabled'
					 );
					 
# Sub-frame for the insert checkbuttons
my $add_sub_frame = $add_keyword_frame->Frame( -relief      => 'flat',
                                               -borderwidth => 1 );

# Sub-frame for the type checkbuttons
my $add_type_frame = $add_keyword_frame->Frame( -relief      => 'flat',
                                               -borderwidth => 1 );

# pack them
$add_label->grid( -column => 0, -row => 0, -sticky => 'e');
$keyword_entry->grid( -column => 1, -row => 0, -sticky => 'ew');                 $value_entry->grid( -column => 2, -row => 0, -sticky => 'ew');                 $comment_entry->grid( -column => 3, -row => 0, -sticky => 'ew'); 
$add_button->grid( -column => 4, -row => 0, -sticky => 'ew'); 
$add_sub_frame->grid( -columnspan => 4, 
                      -column => 0, -row => 1, -sticky => 'nsew' );
$add_type_frame->grid( -columnspan => 4, 
                      -column => 0, -row => 2, -sticky => 'nsew' );
		      
# insert "after X" checkbuttons
my ( $insert_flag, $after_index, $after_key );

# default is to add after index
$insert_flag = 'plain';

my $insert_checkbutton = $add_sub_frame->Checkbutton( -anchor      => 'w',
                                                   -font        => $font,
						    -text        => 'Insert',
						    -selectcolor => 'blue',
						    -onvalue     => 'plain',
				           -variable => \$insert_flag,
					   -command => sub {  });
					   
$insert_checkbutton->grid( -column => 0, -row => 0, -sticky => 'ew' );
          
my $afterindex_checkbutton = $add_sub_frame->Checkbutton( -anchor  => 'w',
                                                  -font        => $font,
						-text  => 'Insert before index',
						    -selectcolor => 'blue',
						    -onvalue     => 'index',
				           -variable => \$insert_flag,
					   -command => sub { });
					   
$afterindex_checkbutton->grid( -column => 1, -row => 0, -sticky => 'ew' );	
my $index_entry = $add_sub_frame->Entry( 
	                                  -exportselection     => 1,
                                          -font                => 'Fixed',
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					  -textvariable => \$after_index,
				          -width               => 4 ); 

$index_entry->grid( -column => 2, -row => 0, -sticky => 'ew' );	 	         
my $afterkey_checkbutton = $add_sub_frame->Checkbutton( -anchor  => 'w',
                                                    -font        => $font,
					-text  => 'Insert after keyword',
						    -selectcolor => 'blue',
						    -onvalue     => 'key',
				           -variable => \$insert_flag,
					   -command => sub { });
					   
$afterkey_checkbutton->grid( -column => 3, -row => 0, -sticky => 'ew' );
	
my $key_entry = $add_sub_frame->Entry( 
	                                  -exportselection     => 1,
                                          -font                => 'Fixed',
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					  -textvariable => \$after_key,
				          -width               => 8 ); 

$key_entry->grid( -column => 4, -row => 0, -sticky => 'ew' );	 
 
# keyword type sub-frame 

# Declare variables
my ( $type_flag );

my $type_label = $add_type_frame->Label( -text => "Type:",
                                         -font         => $font );
$type_label->grid( -column => 0, -row => 0, -sticky => 'ew' ); 

my $int_checkbutton = $add_type_frame->Checkbutton( -anchor      => 'w',
                                                    -font        => $font,
						    -text        => 'INT',
						    -selectcolor => 'blue',
						    -onvalue     => 'int',
				           -variable => \$type_flag,
					   -command => sub { 
			if( defined $new_keyword && defined $new_value
			     ) {		   
				$add_button->configure( -state => 'normal' ); }
					    });
					   
$int_checkbutton->grid( -column => 1, -row => 0, -sticky => 'ew' );

my $float_checkbutton = $add_type_frame->Checkbutton( -anchor      => 'w',
                                                    -font        => $font,
						    -text        => 'FLOAT',
						    -selectcolor => 'blue',
						    -onvalue     => 'float',
				           -variable => \$type_flag,
					   -command => sub { 
			if( defined $new_keyword && defined $new_value
			     ) {		 
			        $add_button->configure( -state => 'normal'); }
					    }); 
					   
$float_checkbutton->grid( -column => 2, -row => 0, -sticky => 'ew' );

my $string_checkbutton = $add_type_frame->Checkbutton( -anchor      => 'w',
                                                    -font        => $font,
						    -text        => 'STRING',
						    -selectcolor => 'blue',
						    -onvalue     => 'string',
				           -variable => \$type_flag,
					   -command => sub { 
			if( defined $new_keyword && defined $new_value
			     ) {		 
				$add_button->configure( -state => 'normal'); }
					    });					   
$string_checkbutton->grid( -column => 3, -row => 0, -sticky => 'ew' );

my $logical_checkbutton = $add_type_frame->Checkbutton( -anchor      => 'w',
                                                    -font        => $font,
						    -text        => 'LOGICAL',
						    -selectcolor => 'blue',
						    -onvalue     => 'logical',
				           -variable => \$type_flag,
					   -command => sub {
			if( defined $new_keyword && defined $new_value
			     ) {		 
				$add_button->configure( -state => 'normal'); }
					    });
					   
$logical_checkbutton->grid( -column => 4, -row => 0, -sticky => 'ew' );          
my $comment_checkbutton = $add_type_frame->Checkbutton( -anchor      => 'w',
                                                    -font        => $font,
						    -text        => 'COMMENT',
						    -selectcolor => 'blue',
						    -onvalue     => 'comment',
				           -variable => \$type_flag,
					   -command => sub {
			if( defined $new_keyword 
			    && defined $new_comment ) {		 
				$add_button->configure( -state => 'normal'); }
					    });
					   
$comment_checkbutton->grid( -column => 5, -row => 0, -sticky => 'ew' );     

# D E L E T E   K E Y W O R D   P A N E L  -----------------------------------

# Add keyword panel, sub-panel of the right main panel
my $del_keyword_frame = $right_frame->Frame( -relief      => 'groove',
                                             -borderwidth => 1 );

$del_keyword_frame->grid( -column => 1, -row => 1, -sticky => 'nsew' );

# Widgets and stuff
my $del_label = $del_keyword_frame->Label( -text => "Delete Header Card",
                                         -font         => $font );
 

my $del_button = $del_keyword_frame->Button(-text             => 'Delete',
                                        -font             => $font,
                                        -activeforeground => 'white',
                                        -activebackground => 'blue',
					-state            => 'disabled'
					 ); 

# Sub-frame for the insert checkbuttons
my $del_sub_frame = $del_keyword_frame->Frame( -relief      => 'flat',
                                               -borderwidth => 1 );

# pack them
$del_label->grid( -column => 0, -row => 0, -sticky => 'e');
$del_button->grid( -column => 1, -row => 0, -sticky => 'ew'); 
$del_sub_frame->grid( -columnspan => 2, 
                      -column => 0, -row => 1, -sticky => 'nsew' );

# Declare variables
my ( $delete_flag, $by_index, $by_key );
$by_index = 0;

# default it to delete by index
$delete_flag = 'index';

# delete checkbuttons
my $byindex_checkbutton = $del_sub_frame->Checkbutton( -anchor  => 'w',
                                                    -font        => $font,
						-text  => 'by index',
						    -selectcolor => 'blue',
						    -onvalue     => 'index',
				           -variable => \$delete_flag,
					   -command => sub { });
					   
$byindex_checkbutton->grid( -column => 0, -row => 0, -sticky => 'ew' );
	
my $byindex_entry = $del_sub_frame->Entry( 
	                                  -exportselection     => 1,
                                          -font                => 'Fixed',
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					  -textvariable => \$by_index,
				          -width               => 4 ); 

$byindex_entry->grid( -column => 1, -row => 0, -sticky => 'ew' );	 	         
my $bykey_checkbutton = $del_sub_frame->Checkbutton( -anchor  => 'w',
                                                    -font        => $font,
					-text  => 'by name',
						    -selectcolor => 'blue',
						    -onvalue     => 'key',
				           -variable => \$delete_flag,
					   -command => sub { });
					   
$bykey_checkbutton->grid( -column => 0, -row => 1, -sticky => 'ew' );
	
my $bykey_entry = $del_sub_frame->Entry( 
	                                  -exportselection     => 1,
                                          -font                => 'Fixed',
				          -selectbackground    => 'blue',
				          -selectforeground    => 'white',
				          -justify             => 'left',
					  -textvariable => \$by_key,
				          -width               => 8 ); 

$bykey_entry->grid( -column => 1, -row => 1, -sticky => 'ew' );	 
      			       
# B U I L D   S T A T U S   B A R --------------------------------------------

# Frame for status bar
my $status_frame = $MW->Frame( -relief      =>'flat', 
                               -borderwidth => 1 );

# Status label
my $status_label = $status_frame->Label( -textvariable => \$CURRENT_STATUS,
                                         -font         => $font,
					 -foreground   => 'blue');
$status_label->pack( -side => 'left'); 

my $file_type = $status_frame->Label( -textvariable => \$FILE_TYPE,
                                         -font         => $font,
					 -foreground   => 'red');

$file_type->pack( -side => 'right'); 

# B I N D   B U T T O N ,   T E X T   E N T R Y   &   L I S T B O X ---------

# Declare header variable and reference to header contents
# F I T S   C A R D S   D E F I N E D   H E R E 
my ( $header, $filename, @cards );

# Bind the directory entry widget to create a file list
$directory_entry->bind( "<Return>", 
     sub { unless ( opendir ( DIR, $working_directory ) ) {
                $MW->Dialog(-title => 'Error',
			  -text => "Directory $working_directory not found\n",
			  -bitmap => 'error',
			  -font => $font)->Show;
                $working_directory = $old_directory;
		return; };
           @file_list = ();
	   @file_list = grep !/^\./, readdir *DIR;
           @file_list = sort ( @file_list );
	   closedir *DIR;
           $old_directory = $working_directory;     
     } );

# Bind the new keyword, value and comment entry widgets to enable the 
# add new keyword button if the $type_flag is defined
$keyword_entry->bind("<KeyPress>",
  sub { $add_button->configure( -state => 'normal' ) if defined $type_flag; });
$value_entry->bind("<KeyPress>",
  sub { $add_button->configure( -state => 'normal' ) if defined $type_flag; });
$comment_entry->bind("<KeyPress>",
  sub { $add_button->configure( -state => 'normal' ) if defined $type_flag; });

# Declare widget variables
my ( $number, $key_widget, $val_widget, $com_widget, $blank );

# Declare tied variables
my ( $header_value, $header_comment );

# Bind the left mouse button click to the Tk::Listbox to do file stuff
$files->bind( "<Double-1>", sub { &$read_file });      	 

# enable the DELETE button when an index or keyword is entered
$byindex_entry->bind( "<Key>",
     sub { $del_button->configure( -state => 'normal' ) if defined $header; });
     
$bykey_entry->bind( "<Key>",
     sub { $del_button->configure( -state => 'normal' ) if defined $header; }); 


# Declare variables
my @card;  # Card(s?) returned after deletion

# Add header card
$add_button->bind( "<ButtonPress>",
        sub {
	 # create a new FITS card
	 my $item = new Astro::FITS::Header::Item( 
	                                 Keyword => uc( $new_keyword ),
					 Value   => $new_value,
					 Comment => $new_comment,
					 Type    => uc( $type_flag ) );

         # modify the status line
         $CURRENT_STATUS = "FITS Editor $VERSION - " .
	                   "Adding keyword " . uc($new_keyword);
	 $MW->update;					 

	 # add by index or keyword
	 if ( $insert_flag eq "plain" ) {
	    $after_index = scalar(@$number)-1; $insert_flag = "index";
	    $header->insert( $after_index, $item ) if defined $item;
	 } elsif ( $insert_flag eq "index" ) {
	    $header->insert( $after_index, $item ) if defined $item;
	 } elsif ( $insert_flag eq "key" ) {    
 	    my @index = $header->index( uc($after_key ) );
	    $header->insert( $index[0]+1, $item ) if defined $item;
	 }

         # update
	 &$update_window;

         # modify the status line
         $CURRENT_STATUS = "FITS Editor $VERSION - " .
                File::Spec->catfile($working_directory, $$file_select[0]);
  	 $MW->update;					

	});
	
# Remove header card
$del_button->bind( "<ButtonPress>", 
        sub {	

           # modify the status line
           $CURRENT_STATUS = "FITS Editor $VERSION - " .
	                     "Deleting keyword " . uc($new_keyword);
	   $MW->update;					 

           # delete by index or keyword
	   if ( $delete_flag eq "index" ) {
	       @card = $header->remove($by_index);	   
	   } elsif ( $delete_flag eq "key" ) {  
	       @card = $header->removebyname(uc($by_key) );
	   }
	   
	   # update
	   &$update_window;

           # modify the status line
           $CURRENT_STATUS = "FITS Editor $VERSION - " .
                  File::Spec->catfile($working_directory, $$file_select[0]);
  	   $MW->update;					

	} );     	 

# Save button 
$save_button->bind( "<ButtonPress>",  sub { &$commit_changes } );

# A N O N Y M O U S  S U B - R O U T I N E -----------------------------------

# anonymous sub-routine to COMMIT CHANGES
$commit_changes = sub {

        if( $save_button->cget( -state ) eq 'active' ||
            $save_button->cget( -state ) eq 'normal' ) {
                  
           # modify the status line
           $CURRENT_STATUS = "FITS Editor $VERSION - " .
	                     "Saving changes to $filename";
	   $MW->update;	

	   # committ changes to file
	   $header->writehdr( File => $filename ) if defined $header;

           # modify the status line
           $CURRENT_STATUS = "FITS Editor $VERSION - " .
                  File::Spec->catfile($working_directory, $$file_select[0]);
  	   $MW->update;	
           
        }				
	$save_button->configure( -state => 'disabled' );
        $menus[0]->menu()->entryconfigure( 1, -state => 'disabled' );

};

# anonymous sub-routine to open a (modified) Tk::FileDialog
$file_request = sub {
           $old_directory = $working_directory;
           	   
           # Create a Tk:FileDialog so we can pop it up when needed
           my $file_chooser = $MW->FileDialog( -Title => 'FITS Editor',
                                               -Create => 0, 
				               -SelDir => 1,
					       -Font => $font);
           ($working_directory, my $fname ) = $file_chooser->Show();
 
           unless ( opendir ( DIR, $working_directory ) ) {
                $MW->Dialog(-title => '',
			  -text => "Directory $working_directory not found\n",
			  -bitmap => 'error',
			  -font => $font)->Show;
                $working_directory = $old_directory;
                return; };
           @file_list = ();
	   @file_list = grep !/^\./, readdir *DIR;
           @file_list = sort( @file_list );
	   closedir *DIR; 
           $old_directory = $working_directory;    
};

# anonymous sub-routine to read a file
$read_file = sub {
	   # modify the status line			
	   $status_label->configure( -foreground => 'red' );
	   $CURRENT_STATUS = "FITS Editor $VERSION - " .
	                     "Reading file, please wait";
	   undef $FILE_TYPE;

           # update the window
	   $MW->update;
	   
	   # check to see if we have previously displayed a FITS header
	   # and if so delete all the widgets
           if ( defined $number ) {
	      $$blank->destroy if defined $$blank;
              for my $i ( 0 .. scalar(@$number)-1 ) {
                 $$number[$i]->destroy if defined $$number[$i];
	         $$key_widget[$i]->destroy if defined $$key_widget[$i];
                 $$val_widget[$i]->destroy if defined $$val_widget[$i];
	         $$com_widget[$i]->destroy if defined $$com_widget[$i];
              }
		 
              # disable the "Save Changes" button on the keyword_widget
              # since we now have a fresh header and no changes have
	      # been made as yet.
              $save_button->configure( -state => 'disabled' );               
              $menus[0]->menu()->entryconfigure( 1, -state => 'disabled' );
              
	      # undef the destroyed widgets in case we're changing directory
	      # so we don't try and destroy them again when the next file
	      # is selected.
	      @$number = ();
              @$key_widget = ();
	      @$val_widget = ();
	      @$com_widget = ();
	      $blank = ();
		 
	      # undef $header
	      undef $header;
	   }

           # check we have a file
	   if ( -f File::Spec->catfile($working_directory,$$file_select[0]))
	   {		 
	      # open the new header, returning the contents in array
	      ( $header, $filename) = 
		editor_open_header( $file_select, $working_directory,
		                    \$FILE_TYPE, $MW, $font );
		
	      if ( defined $header ) {
 
	         # enable DELETE button
		 if ( defined $by_index || defined $by_key ) {
		    $del_button->configure( -state => 'normal' ); }
		    
                 # pull the FITS cards from the header
                 @cards = $header->allitems();
		 $FILE_TYPE = $FILE_TYPE . ", Cards: " . $#cards . ' ';
		    
	         # display the header inside the keyword_widget Tk::Pane	
	         ( $number, $key_widget, $val_widget, $com_widget, $blank,
		   $header_value, $header_comment ) =
	              editor_display_header( \@cards, $keyword_widget, $font );
                 
	         # modify the status line			
	         $status_label->configure( -foreground => 'blue' );
                 $CURRENT_STATUS = "FITS Editor $VERSION - " .
	           File::Spec->catfile($working_directory, $$file_select[0]);
                 $MW->update;

                 # Bind the value and comment widgets to modify the header
                 for my $i ( 0 .. scalar(@$number)-1 ) {

                    # value widgets
                    $$val_widget[$i]->bind( "<Return>", 
                    sub {	
	
	               $cards[$i]->value($$header_value[$i]);

	               # rebuild the keyword widget
                       &$update_window;
           
	            } ) if defined $$val_widget[$i];

                    # comment widgets	
                    $$com_widget[$i]->bind( "<Return>", 
                    sub {	
	
	               $cards[$i]->comment($$header_comment[$i]);

	               # rebuild the keyword widget
                       &$update_window;
	   
	            } )  if defined $$com_widget[$i];
                 }
		    
              } else {
		 # modify the status line
		 $CURRENT_STATUS = "FITS Editor $VERSION - " .
		    "Unable to load selected file";
	         $MW->update;
              }		
	 }
	 # or a directory 
	 elsif ( -d File::Spec->catfile($working_directory,$$file_select[0]))
	 {
	      # its a directory, open it
              my $new_directory = 
		  File::Spec->catfile( $working_directory,$$file_select[0] );
              unless ( opendir ( DIR, $new_directory ) ) {
                $MW->Dialog(-title => 'Error',
			  -text => "Directory $new_directory not found\n",
			  -bitmap => 'error',
			  -font => $font)->Show;
                $working_directory = $old_directory;
                return; };
                 
	      # modify the status line
              $status_label->configure( -foreground => 'blue' ); 		
	      $CURRENT_STATUS = "FITS Editor $VERSION - " .
	                        "no file selected";
              $MW->update;
		 
              # grab a new file list
	      @file_list = ();
	      @file_list = grep !/^\./, readdir *DIR;
              @file_list = sort ( @file_list );
              $working_directory = $new_directory;
              $old_directory = $working_directory;
	      closedir *DIR; 
	 }	 	  
};
	    
# anonymous sub-routine to update the header pane
$update_window = sub {

	   # rebuild the keyword widget
           &$rebuild_widgets;

           # Bind the value and comment widgets to modify the header
           for my $i ( 0 .. scalar(@$number)-1 ) {

              # value widgets
              $$val_widget[$i]->bind( "<Return>", 
              sub {	
	
	         $cards[$i]->value($$header_value[$i]);

	         # rebuild the keyword widget
                 &$update_window;
           
	      } ) if defined $$val_widget[$i];

              # comment widgets	
              $$com_widget[$i]->bind( "<Return>", 
              sub {	
	
	         $cards[$i]->comment($$header_comment[$i]);

	         # rebuild the keyword widget
                 &$update_window;
	   
	      } )  if defined $$com_widget[$i];
           }
                 	
           # activate the "Commit Changes" button
	   $save_button->configure( -state => 'normal' );
           $menus[0]->menu()->entryconfigure( 1, -state => 'normal' );
	   	   
};


# rebuild the keyword, value and comment widgets from modified header
$rebuild_widgets = sub {

   $$blank->destroy if defined $$blank;
   for my $i ( 0 .. scalar(@$number)-1 ) {
      $$number[$i]->destroy if defined $$number[$i];
      $$key_widget[$i]->destroy if defined $$key_widget[$i];
      $$val_widget[$i]->destroy if defined $$val_widget[$i];
      $$com_widget[$i]->destroy if defined $$com_widget[$i];
   }
   # undef the destroyed widgets 
   @$number = ();
   @$key_widget = ();
   @$val_widget = (); 
   @$com_widget = ();
   $blank = ();
    
   # pull the FITS cards from the header
   @cards = $header->allitems();
   ( $FILE_TYPE, my $dummy ) = split( /,/, $FILE_TYPE );
   $FILE_TYPE = $FILE_TYPE . ', Cards: ' . $#cards . ' ';
    	   
   # display the header inside the keyword_widget Tk::Pane	  
   ( $number, $key_widget, $val_widget, $com_widget, $blank,
     $header_value, $header_comment  ) =
	        editor_display_header( \@cards, $keyword_widget, $font );
                 	
};

# P A C K  M A I N  W I N D O W ---------------------------------------------

# pack the menu frame
$menu_frame->grid( -column => 0, -row => 0, -columnspan => 2, -sticky => 'ew' );

# pack the label frame
$label_frame->grid( -column => 0, -row => 1, -columnspan => 2, -sticky => 'ew');

# pack the holding frame
$main_frame->grid( -column => 0, -row => 2, -sticky => 'nsew' );

# pack the status frame
$status_frame->grid( -column => 0, -row => 3, -columnspan => 2, -sticky =>'ew');
$CURRENT_STATUS = "FITS Editor $VERSION - no file selected";

# E N D ---------------------------------------------------------------------

# Set working directory if -dir option used
if ( defined $opt{"dir"} ) {
   unless ( opendir ( DIR, $working_directory ) ) {
      $MW->Dialog( -title => 'Error',
   		   -text => "Directory $working_directory not found\n",
   		   -bitmap => 'error',
		   -font => $font)->Show;
      $working_directory = undef;
   };
   @file_list = ();
   @file_list = grep !/^\./, readdir *DIR;
   @file_list = sort ( @file_list );
   closedir *DIR;
   $old_directory = $working_directory;     
};


# Set selected file if -file option used
if ( defined $opt{"file"} ) {
    $file_select = [ $opt{"file"} ];
    &$read_file 
}; 
    
# Enter the Tk mainloop
MainLoop();

# T I M E   A T   T H E   B A R  -------------------------------------------

# $Log$
# Revision 1.5  2002/09/16 03:48:09  timj
# Fix pod
#
# Revision 1.4  2001/10/24 19:52:43  allan
# Quick fix to the font problem
#
# Revision 1.3  2001/10/24 14:35:24  allan
# Re-integrate FITS Editor into ORAC-DR tree post-ADASS XI
#
# Revision 1.1  2001/07/02 23:09:08  allan
# FITS Editor, basic functionality only. Menus not working
#

