#!/usr/bin/perl

use strict;
use warnings;


my $operation = shift ||die "ERROR: Must specify an operation of {union,intersection,difference,sum}\n";

my $primary = shift || die "ERROR: Must specify at least one input set.\n";

my @secondaries = @ARGV;

# hash by part_id and color_name
my %part_hash = ();

# parse the primary to populate the working set.
sub parse_input {
  my ($fname) = @_;

  my %results = ();

  my $pfh;
  open($pfh, "<", $fname) or die "ERROR: Unable to open [$fname] for reading.\n";
  while(<$pfh>) {
    chomp;
    if(/^\s*([^\s]+)\s+([^\s]+)\s+([[:digit:]]+)\s+([^\s]+)\s+([^\s]+)\s+"(.*)"\s*$/) {
      my ($pid,$uid,$qty,$type,$color,$desc) = ($1,$2,$3,$4,$5,$6);
      if(!defined $results{$pid.$color}) {
        $results{$pid.$color} = {part_id=>$pid,uid=>$uid,qty=>$qty,type=>$type,color=>$color,desc=>$desc, hits=>1};
      } else {
        $results{$pid.$color}->{qty} += $qty;
        if($results{$pid.$color}->{type} ne $type) {
          $results{$pid.$color}->{type} .= ",$type";
        }
      }

    } else {
      die "ERROR: While parsing [$fname], found a line I don't understand [$_]\n";
    }
  }
  close($pfh);

  return %results;
}

%part_hash = parse_input($primary);

# for each secondary, parse it and operate between it and the working set
foreach(@secondaries) {
  my $s = $_;

  my %temp_hash = parse_input($s);

  foreach(keys %temp_hash) {
    my $k = $_;
    my $se = $temp_hash{$k};
    my $pe = $part_hash{$k};

    my $sq = $se->{qty};
    my $pq = defined $pe ? $pe->{qty} : 0;

    if($operation eq "union") {
      if(!defined $pe) {
        # if the working set doesn't have this one, just use ours
        $part_hash{$k} = $se;
      } else {
        # if both have it, chose the max qty one to keep
        $part_hash{$k}->{qty} = $sq > $pq ? $sq : $pq;
      }

    } elsif($operation eq "intersection") {
      if(!defined $pe) {
        # if the working set doesn't have this one, the intersection is 0
      } else {
        # if it does, choose the min and up the hit count
        $part_hash{$k}->{qty} = $sq < $pq ? $sq : $pq;
        $part_hash{$k}->{hits} += 1;
      }
    } elsif($operation eq "difference") {
      if(!defined $pe) {
        # if the working set doesn't have this one, that's fine, leave it at 0
      } else {
        # if it does, remove our qty, bounded by 0 at the low side.
        $part_hash{$k}->{qty} = $pq > $sq ? ($pq-$sq) : 0;
      }
    } elsif($operation eq "sum") {
      if(!defined $pe) {
        # if the working set doesn't have this one, just use ours
        $part_hash{$k} = $se;
      } else {
        # if it does, add our qty on to it
        $part_hash{$k}->{qty} += $sq;
      }
    } else {
      die "ERROR: Don't know how to perform operation [$operation]\n";
    }
  }

}

if($operation eq "intersection") {
  my $desired_hits = 1 + (scalar @secondaries);

  # now go back through everything in the working set.
  # if some part doesn't have a hit from everybody, somebody
  # must have had a 0, so set the qty to 0.
  foreach(keys %part_hash) {
    my $k = $_;
    my $pe = $part_hash{$_};
    my $ph = $pe->{hits};

    if($ph < $desired_hits) {
      # whoops somebody was missing this part
      $part_hash{$k}->{qty} = 0;
    }
  }
}

# display the resultant state of the working set.
foreach(sort keys %part_hash) {
  my $e=$part_hash{$_};
  if(defined $e && $e->{qty} > 0) {
    printf "%-10s %-10s %5d %6s %-20s \"%s\"\n", $e->{part_id}, $e->{uid},$e->{qty},$e->{type},$e->{color},$e->{desc};
  }

}

exit 0;

