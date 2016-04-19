#!/usr/bin/perl

use strict;
use warnings;
use Rebrickable;

#$Rebrickable::SHOW_CALLS = 1;

my $operation = shift ||die "ERROR: Must specify an operation of {union,intersection,difference,sum}\n";

my $primary = shift || die "ERROR: Must specify at least one input set.\n";

my @secondaries = @ARGV;

# hash by part_id and color_name
my %part_hash = ();

sub parse_input {
  my ($set_id) = @_;

  my %parts = ();

  my $results = Rebrickable::get_set_parts($set_id);

  if($results->{code} == 200 && defined $results->{data}) {

      foreach(@{$results->{data}->[0]->{parts}}) {
        my $e = $_;
        my $c = $e->{color_name};
        $c =~ s/\s/_/g;
        my $k = $e->{part_id}.$c;

        if(!defined $parts{$k}) {
          $parts{$k} = {part_id=>$e->{part_id},uid=>$e->{element_id},qty=>$e->{qty},type=>$e->{type},color=>$c,desc=>$e->{part_name}, hits=>1, sets=>[$set_id]};
        } else {
          $parts{$k}->{qty} += $e->{qty};
          if($parts{$k}->{type} ne $e->{type}) {
            $parts{$k}->{type} .= ",$e->{type}";
          }
        }
      }
  }

  return %parts;
}

# parse the primary to populate the working set.
%part_hash = parse_input($primary);

# Cache of part relationship lookups.  Each entry is a part_id->[related_part_ids...] mapping.
# Just MOLD rel_types are included, and are assumed to be transitive
my %part_related = ();

sub check_related {
  my ($part_id) = @_;

  if(!defined $part_related{$part_id}) {
    # Need to do the lookup
    my $results = Rebrickable::get_part($part_id);
    if($results->{code} == 200 && defined $results->{data}) {
      my @related = ();
      foreach(@{$results->{data}->{related_parts}}) {
        if($_->{related_to}->{rel_type} eq "MOLD") {
          push @related, $_->{related_to}->{part_id};
        }
      }

      if(scalar @related) {
        push @related, $part_id;
      }

      foreach(@related) {
          $part_related{$_} = [@related];
      } 
    }
  }

  return defined $part_related{$part_id} ? @{$part_related{$part_id}} : ();
}

# for each secondary, parse it and operate between it and the working set
foreach(@secondaries) {
  my $s = $_;

  my %temp_hash = parse_input($s);

  foreach(keys %temp_hash) {
    my $k = $_;
    my $se = $temp_hash{$k};
    my $pe = $part_hash{$k};

    # ok, if we don't find an exact match in the part_hash, check for related parts
    if(!defined $pe) {
      my @related = check_related($se->{part_id});
      my $color = $se->{color};

      RELATED: foreach(@related) {
        my $k2 = $_.$color;
        $pe = $part_hash{$k2};
        last RELATED if defined $pe;
      }
    }

    my $sq = $se->{qty};
    my $pq = defined $pe ? $pe->{qty} : 0;

    if($operation eq "union") {
      if(!defined $pe) {
        # if the working set doesn't have this one, just use ours
        $part_hash{$k} = $se;
      } else {
        # if both have it, chose the max qty one to keep
        $pe->{qty} = $sq > $pq ? $sq : $pq;
        push @{$pe->{sets}}, $s;
      }

    } elsif($operation eq "intersection") {
      if(!defined $pe) {
        # if the working set doesn't have this one, the intersection is 0
      } else {
        # if it does, choose the min and up the hit count
        $pe->{qty} = $sq < $pq ? $sq : $pq;
        $pe->{hits} += 1;
      }
    } elsif($operation eq "difference") {
      if(!defined $pe) {
        # if the working set doesn't have this one, that's fine, leave it at 0
      } else {
        # if it does, remove our qty, bounded by 0 at the low side.
        $pe->{qty} = $pq > $sq ? ($pq-$sq) : 0;
      }
    } elsif($operation eq "sum") {
      if(!defined $pe) {
        # if the working set doesn't have this one, just use ours
        $part_hash{$k} = $se;
      } else {
        # if it does, add our qty on to it
        $pe->{qty} += $sq;
        push @{$pe->{sets}}, $s;
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
    printf "%-10s %-10s %5d %6s %-20s \"%s\" %s\n", $e->{part_id}, $e->{uid},$e->{qty},$e->{type},$e->{color},$e->{desc}, join(',',@{$e->{sets}});
  }

}

exit 0;

