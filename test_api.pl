#!/usr/bin/perl

use strict;
use warnings;
use Rebrickable;

my $op = shift;

$Rebrickable::VERBOSITY=3;

my $parms = {};

while(1) {
  my $k = shift;
  my $v = shift;

  last if !defined $k || !defined $v;

  $parms->{$k} = $v;

}

my $results = Rebrickable::call_api($op,"GET",$parms);

exit 0;

