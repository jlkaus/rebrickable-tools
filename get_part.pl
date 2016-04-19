#!/usr/bin/perl

use strict;
use warnings;
use Rebrickable;

my $part_id = shift;
my $verbose = shift;

my $results = Rebrickable::get_part($part_id, $verbose);
if($results->{code} != 200 || $results->{raw_data} =~ /NOPART/) {
  chomp $results->{raw_data};
  die "ERROR: get_part API got rc=$results->{code} [$results->{message}] ($results->{raw_data})\n";
}

my $e = $results->{data};
printf("%-10s %-4s %-20s %4d - %4d \"%s\"\n", $e->{part_id}, $e->{part_type_id}//"-", "\"$e->{category}\"", $e->{year1}, $e->{year2}, $e->{name});

my %rels = ();
foreach(@{$e->{related_parts}}) {
  my $f = $_;
  my $k = $f->{related_to}->{part_id}.$f->{related_to}->{rel_type};

  if(!defined $rels{$k}) {
    $rels{$k} = 1;
    printf("\t%-10s %-10s\n", $f->{related_to}->{part_id}, $f->{related_to}->{rel_type});
  }
}

exit 0;

