#!/usr/bin/env perl

use strict;
use warnings;

my $RED = "\e[01;31m";
my $PURPLE = "\e[35m";
my $GREEN =  "\e[32m";
my $BOLD_WHITE = "\e[37;40m";
my $OFF = "\e[m";

sub color_id     { $_[0] }
sub color_lineno { $GREEN . $_[0] . $OFF }
sub color_path   { $PURPLE . $_[0] . $OFF }
sub color_match  { $RED . $_[0] . $OFF }

sub match_to_string {
  my ($m) = @_;

  my $buf = "id $m->{id}\npath $m->{path}\n";
  $buf .= "lineno $m->{lineno}\n" if defined($m->{lineno});
  $buf .= "offset $m->{offset}\n" if defined($m->{offset});
  $buf .= "end\n";

}

sub write_match {
  my ($fh, $m) = @_;

  print {$fh} match_to_string($m);
}

# parse ackmate results

sub process_ackmate {
  my ($fh, $mfh) = @_;
  my $path = "";
  my $id = 0;

  while (<$fh>) {
    chomp;
    if (m/^:/) {
      $path = substr($_, 1)
    } elsif (s/^(\d+);(.*?)://) {
      $id++;
      my $lineno = $1;
      my $ranges = $2;
      my $text = $_;

      # parse the ranges
      my @ranges;
      while ($ranges =~ m/(\d+) (\d+)/g) {
        push(@ranges, [$1, $2]);
      }

      # create the highlighted string
      my $i = 0;
      my $str = "";
      for (@ranges) {
        # warn "\$_ = " . Dumper(\$_) . "\n"; use Data::Dumper;
        $str .= substr($text, $i, $_->[0] - $i) . color_match( substr($text, $_->[0], $_->[1]) );
        $i = $_->[0] + $_->[1];
      }
      $str .= substr($text, $i);

      # emit the match
      my $out = color_id($id) . " " . color_path($path) . ":" . color_lineno($lineno) . ":" . $str;
      print $out, "\n";

      # append the match
      my $m = { id => $id, path => $path, lineno => $lineno };
      write_match($mfh, $m);
    }
  }
}

sub main {
  unless (@ARGV) {
    my $leaf = ($0 =~ s,.*/,,);
    die "Usage: $leaf [ag options...]\n";
  }
  unless ($ENV{MTAGS}) {
    die "environment variable MTAGS not defined\n";
  }
  open(my $fh, "-|", "ag", "--ackmate", @ARGV);
  open(my $mfh, ">", $ENV{MTAGS});
  process_ackmate($fh, $mfh);
}

main();

