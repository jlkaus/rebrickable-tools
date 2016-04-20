#!/usr/bin/perl

use strict;
use warnings;
use Rebrickable;

my $verbose = shift;

my $results = Rebrickable::get_user_setlists($verbose);
if($results->{code} != 200) {
  die "ERROR: get_user_setlists API got rc=$results->{code} [$results->{message}]\n";
}

foreach(@{$results->{data}->{sets}}) {
  my $e = $_;

  printf("%3d %d \"%s\"\n", $e->{setlist_id}, $e->{type}, $e->{name});
}


exit 0;

