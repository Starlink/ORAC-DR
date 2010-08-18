package Tk::ORAC::RecipeSelect;

# ---------------------------------------------------------------------------

use strict;                  # smack! Don't do it again!
use Carp;                    # Transfer the blame to someone else

# P O D  D O C U M E N T A T I O N ------------------------------------------

=head1 NAME

Tk::ORAC::RecipeSelect - composite widget used by Xoracr

=head1 SYNOPSIS

   use Tk;
   require Tk::ORAC::RecipeSelect;

a new widget can be generated in two ways, either

   my $widget = Tk::ORAC::RecipeSelect->new($MW, -instrument => $instrument);

or

   my $widget = $MW->ORACRecipeSelect(-instrument => $instrument);

Pay attention to the modified name of the widget if you use the autoload
option. The widget method C<Show> returns a selected recipe and path, e.g.

   my ($directory, $recipe) = $widget->Show;

=cut

# L O A D  M O D U L E S ---------------------------------------------------

#
#   ORAC modules
#
use ORAC::Inst::Defn qw/ orac_determine_recipe_search_path /;
use ORAC::Error;
use ORAC::Constants qw/:status/;
use ORAC::Xorac;

#
#   Tk modules
#
use Tk;
require Tk::Toplevel;
require Tk::Label;
require Tk::Listbox;
require Tk::Scrollbar;
require Tk::Button;

#
#   Version
#
use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

#
#   Widget Constructor
#
use base qw/Tk::Toplevel/;
Construct Tk::Widget 'ORACRecipeSelect';

# S U B R O U T I N E S -----------------------------------------------------

sub Populate {

  my ($self, $args ) = @_;

  # Custom widget option
  my $instrument = delete $args->{"-instrument"};

  # Generic widget options
  $self->SUPER::Populate($args);
  $self->protocol('WM_DELETE_WINDOW' => ['Cancel', $self ]);

  # hide until "Show" called
  $self->withdraw;

  # Label
  # -----

  my $label_text = "Choose a directory: ";
  my $label = $self->Label( -textvariable    => \$label_text,
			    -relief  => 'flat',
		            -justify => 'left',
			    -anchor  => 'w',
		            -borderwidth => 5 );
  $label->grid( -column => 0 ,-row => 0, -columnspan => 2, -sticky => 'nsew' );
  # Listbox frame
  # -------------

  my $lbox_frame = $self->Frame( -relief => 'flat', -borderwidth => 2 );
  $lbox_frame->grid( -column => 0, -row => 1,  -columnspan => 2,
                     -sticky => 'nsew' );

  # Tied listbox
  # ------------

  # Directory listing
  my ( $selected, @contents );

  my @dir_list = orac_determine_recipe_search_path($instrument);
  push ( @dir_list, $ENV{"ORAC_RECIPE_DIR"} )
                     if defined $ENV{"ORAC_RECIPE_DIR"};

  # Make sure all directories exist (allows us to remove ORAC_DATA_OUT
  # if it is not set yet)
  @dir_list = grep { -d $_ } @dir_list;

  # Scrolled listbox
  my $scrollbar = $lbox_frame->Scrollbar();

  my $lbox = $lbox_frame->Listbox( -borderwidth         => 1,
                                   -selectbackground    => 'blue',
	 		           -selectforeground    => 'white',
			           -selectmode          => 'single',
				   -height              => 10,
				   -width               => 35,
				   -yscrollcommand      => ['set'=>$scrollbar]);
  $lbox->insert('end',sort @dir_list);

  $scrollbar->configure( -command => [ 'yview' => $lbox ]);

  tie $selected, "Tk::Listbox", $lbox;
  tie @contents, "Tk::Listbox", $lbox;

  # Pack the listbox frame (scrollbar first)
  $scrollbar->grid( -column => 1, -row => 0, -sticky => 'ns' );
  $lbox->grid( -column => 0, -row => 0 , -sticky => 'nsew');

  # Cancel button
  # --------------
  my $cancel_button = $self->Button( -text             =>'Cancel',
			             -activeforeground => 'white',
                                     -activebackground => 'blue',
	 	                     -command => [ "Cancel", $self ] );
  $cancel_button->grid( -column => 0 ,-row => 2, -sticky => 'e' );

  # OK button
  # ---------
  my $ok_button = $self->Button( -text             => 'OK',
			         -activeforeground => 'white',
                                 -activebackground => 'blue' );

  my ( $flag, $filename, $directory );

  # ok_button subroutines
  my ( $sub_ok1, $sub_ok2 );
  $sub_ok1 =  sub {
                   if ( defined $$selected[0] ) {
                           # label text
                           $label_text = "Choose a recipe: ";

                           # access the directory
                           $self->{Directory} = $$selected[0];
                           opendir ( DIR, $self->{Directory}) or
                           throw ORAC::Error::FatalError(
			               " Directory $$selected[0] not found",
                                       ORAC__FATAL );

                           # directory listing
                           @contents = ();
                           foreach ( readdir DIR ) {
                              push( @contents, $_ )
                                          if -T File::Spec->
		                              catfile($self->{Directory},$_); }
                            closedir DIR;

                           # re-configure the OK button
                           $ok_button->configure(-command => sub { &$sub_ok2;});
			   # reconfigure double click
			   $lbox->bind("<Double-Button-1>", sub { &$sub_ok2; });
                   } };

   $sub_ok2 = sub { if ( defined $$selected[0] ) {
			        # get the filename
			        $self->{Filename} = $$selected[0];
			        # untie variables
			        untie @contents;
			        untie $selected; }};

   $ok_button->configure( -command => sub { &$sub_ok1; } );
   $ok_button->grid( -column => 1 ,-row => 2, -sticky => 'we' );

   # Bind Double-Button-1 'cause Tim wants it so...
   $lbox->bind("<Double-Button-1>", sub { &$sub_ok1; } );

   # Composite widget
   # ----------------

   # currently no way to modify any of the default options of this
   # composite widget as I can't really be bothered writing something
   # I'm not going to use right now, the framework is there if anybody
   # actually wants to do something like that.
}

sub Cancel {
   my ($self) = @_;
   $self->{Directory} = undef;
   $self->{Filename} = undef;
   $self->withdraw;
}

sub Show {
  my ($self, @args) = @_;
  $self->Popup(@args);
  $self->focus;
  $self->waitVariable(\$self->{Filename});
  $self->withdraw;
  return ($self->{Directory}, $self->{Filename});
}

# ----------------------------------------------------------------------------

1;
