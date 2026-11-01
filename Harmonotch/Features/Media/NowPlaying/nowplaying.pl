#!/usr/bin/perl
# Loads the Now Playing adapter into perl and hands it the terminal pipes.
# perl is an Apple platform binary, so MediaRemote answers it where it no
# longer answers the app (macOS 15.4+). See NowPlayingAdapter.m.
use strict;
use warnings;
use DynaLoader;

$| = 1;

my $library = shift @ARGV;
die "usage: nowplaying.pl <adapter library>\n"
    unless defined $library && -f $library;

my $handle = DynaLoader::dl_load_file($library, 0)
    or die "nowplaying: cannot load adapter: " . DynaLoader::dl_error() . "\n";
my $symbol = DynaLoader::dl_find_symbol($handle, "hnp_run")
    or die "nowplaying: adapter entry point missing: " . DynaLoader::dl_error() . "\n";
DynaLoader::dl_install_xsub("main::hnp_run", $symbol);
hnp_run();
