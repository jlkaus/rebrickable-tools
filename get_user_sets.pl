#!/usr/bin/perl

use strict;
use warnings;
use Rebrickable;
use Data::Dumper;

my $setlist_id = shift || undef;
my $verbose = shift;

my $results = Rebrickable::call_api("get_user_sets","GET",{setlist_id=>$setlist_id}, $verbose);
if($results->{code} != 200) {
  die "ERROR: get_user_sets API got rc=$results->{code} [$results->{message}]\n";
}

if($verbose) {
  print Dumper($results->{data});
}

foreach(@{$results->{data}->[0]->{sets}}) {
  my $e = $_;

  printf("%-10s %5d %4d \"%s\"\n", $e->{set_id}, $e->{pieces}, $e->{year}, $e->{descr});
}


exit 0;

