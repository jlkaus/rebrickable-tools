#!/usr/bin/perl

use strict;
use warnings;
use Rebrickable;

my $set_id = shift || undef;
my $verbose = shift;

my $results = Rebrickable::get_set_parts($set_id, $verbose);
if($results->{code} != 200) {
  die "ERROR: get_set_parts API got rc=$results->{code} [$results->{message}]\n";
}

foreach(@{$results->{data}->[0]->{parts}}) {
  my $e = $_;

  my $c = $e->{color_name};
  $c =~ s/\s/_/g;

  printf("%-10s %-10s %5d %4d %-20s \"%s\"\n", $e->{part_id}, $e->{element_id}, $e->{qty}, $e->{type}, $c, $e->{part_name});
}


exit 0;

