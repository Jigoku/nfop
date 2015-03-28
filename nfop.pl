#!/usr/bin/env perl
# nfop v0.2
# A gtk2/perl based nfo viewer
#
# Copyright (C) 2015 Ricky K. Thomson
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# u should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


use strict;
use warnings;
use utf8;

use Gtk2 qw(init);
use FindBin qw($Bin); 
use File::Basename;

my $version	= "0.2";

my $data = $Bin . "/data/";
#my $data = "/usr/local/share/nfop/data/";
my $xml	= $data . "gui.xml";
my $conf = $ENV{ HOME } . "/.nfop";

if ( ! -e $xml ) { die "[-] Interface: '$xml' $!"; }

if ( ! -e $conf ) { 
	print "creating config: " . $conf . "\n"; 
	open FILE, ">", $conf or warn $!; 
	print FILE "font=\"Monospace 7\"\n";
	print FILE "bg=\"#000000000000\"\n";
	print FILE "fg=\"#f000f000f000\"\n";
	close FILE;
}

my (
	$builder, 
	$window, 
	$filechooser,
	$textview,
	$fontbutton,
	$buffer,
	$conf_bg,
	$conf_fg,
	$conf_font,
);

my $text = "";

load_config();
main();
gtk_main_quit();


sub load_config {
	# read "~/.nfop" settings
	open FILE, "<$conf" or die "[-] Could not open filename: $!\n";
	foreach my $line (<FILE>) {
		if ($line =~ m/^font=\"(.+)\"/) { $conf_font = $1; } 
		if ($line =~ m/^bg=\"(.+)\"/) { $conf_bg = $1; }
		if ($line =~ m/^fg=\"(.+)\"/) { $conf_fg = $1; }
	}
}

sub main {
	
	$builder = Gtk2::Builder->new();
	
	# load glade XML
	$builder->add_from_file( $xml );

	# get top level object
	$window = $builder->get_object( 'window' );
	$builder->connect_signals( undef );

	# set the application icon
	$window->set_default_icon(
		Gtk2::Gdk::Pixbuf->new_from_file($data."icon48.png");
	);

	# object definitions
	$filechooser = $builder->get_object( 'filechooserdialog' );
	$textview = $builder->get_object( 'textview' );
	$fontbutton = $builder->get_object('fontbutton');
	$buffer = $textview->get_buffer;
	
	# appplication defaults
	$window->set_default_size(425, 450);

	#font
	set_default_font($conf_font);

	#default foreground
	$builder->get_object( 'colourbutton_fg' )->set_color(
		Gtk2::Gdk::Color->parse($conf_fg)
	);
	
	#default background
	$builder->get_object( 'colourbutton_bg' )->set_color(
		Gtk2::Gdk::Color->parse($conf_bg)
	);

	set_bg_colour();
	set_fg_colour();

	# draw the window
	$window->show_all();

	# main loop
	Gtk2->main();
}

sub on_about_clicked {
	# launch about dialog
	my $about = $builder->get_object( 'aboutdialog' );
	$about->run;
	# make sure it goes away when destroyed
	$about->hide;
}

sub on_openfile_clicked {
	# filerchooser filter
	my $filternfo = Gtk2::FileFilter->new();
	$filternfo->add_pattern("*.nfo");
	$filternfo->set_name("nfo files");

	# filerchooser filter
	my $filterall = Gtk2::FileFilter->new();
	$filterall->add_pattern("*");
	$filterall->set_name("all");
	
	$filechooser->add_filter($filternfo);
	$filechooser->add_filter($filterall);
	$filechooser->run;
	
	# make sure it goes away when destroyed
	$filechooser->hide;
}

sub on_button_openfile_clicked($) {
	$filechooser->hide;
	
	# open the file with codepage 437 encoding
	open FILE, "<:encoding(CP437)", $filechooser->get_filename or die $!;
	
	# reinitialize
	$text = "";
	
	while (<FILE>){
		# parse to a string
		$text .= $_;
	}
	
	close FILE;
	
	my $buffer = $textview->get_buffer;
	
	# set the textview buffer
	$buffer->set_text($text);
	
	# update the colour
	set_fg_colour();
	
	# show filename in statusbar
	$builder->get_object( 'status_label' )->set_text(
		basename($filechooser->get_filename)
	);
}

sub on_fontbutton_font_set {
	set_textview_font($fontbutton->get_font_name);
	$conf_font = $fontbutton->get_font_name;
}



sub set_textview_font($) {
	# convert font string to font
	$textview->modify_font(	
		Gtk2::Pango::FontDescription->from_string(
			shift
		)
	);
}

sub set_bg_colour {
	# sets the background colour of the textview widget
	my $colour = $builder->get_object( 'colourbutton_bg' )->get_color->to_string;
	
	# update config var
	$conf_bg = $colour;
	
	# convert #000000000000 to 0x0000 0x0000 0x0000 as hex
	my $red = substr($colour, 1, 4);
	my $green = substr($colour, 5, 4);
	my $blue = substr($colour, 9, 4);
	
	# background
	$textview->modify_base(
		'normal',
		Gtk2::Gdk::Color->new(hex($red),hex($green),hex($blue))
	);
	
	# padding
	$textview->modify_bg(
		'normal',
		Gtk2::Gdk::Color->new(hex($red),hex($green),hex($blue))
	);
	
}

sub set_fg_colour {
	# not implemented
	my $colour = $builder->get_object( 'colourbutton_fg' )->get_color->to_string;
	
	# update config var
	$conf_fg = $colour;
	
	my $red = substr($colour, 1, 4);
	my $green = substr($colour, 5, 4);
	my $blue = substr($colour, 9, 4);
	
	# create a tag to hold the custom colour
	# we get segfaults if the tag exists, so this hack
	# just makes a randomly named tag.
	my $tag = $buffer->create_tag (
		rand(10000)."_foreground", 
		foreground => Gtk2::Gdk::Color->parse($colour)->to_string
	);
	
	# apply the tag to entire buffer
	my $start = $buffer->get_iter_at_offset (0);
	my $end = $buffer->get_iter_at_offset (length($text));
    $buffer->apply_tag ($tag, $start, $end);

}

sub set_default_font($) {
	# set the default font
	my $font = shift;
	$fontbutton->set_font_name($font);
	set_textview_font($font);
}

sub on_menuitem_statusbar_activate {
	my $sb = $builder->get_object( 'statusbar' );
	
	# toggle visibility of the statusbar
	if ($sb->visible == 1) {
		$sb->hide_all(); 
	} else { 
		$sb->show_all(); 
	}
}

sub on_menuitem_copy_activate {
	# create a clipboard object
	my $clipboard =  Gtk2::Clipboard->get(Gtk2::Gdk->SELECTION_CLIPBOARD);
	
	# set selected text to the clipboard
	my $buffer = $textview->get_buffer;
	$buffer->copy_clipboard($clipboard);
}

sub gtk_main_quit {
	# store changed settings
	open FILE, ">$conf" or die "[-] Could not open filename: $!\n";
	print FILE "font=\"$conf_font\"\n";
	print FILE "bg=\"$conf_bg\"\n";
	print FILE "fg=\"$conf_fg\"\n";
	close FILE;
	
	# cleanup and exit
	$window->destroy; Gtk2->main_quit();
	exit(0);
}


#EOF#


