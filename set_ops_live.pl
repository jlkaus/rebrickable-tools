#!/usr/bin/perl

use strict;
use warnings;
use Rebrickable;

#$Rebrickable::SHOW_CALLS = 1;


my $trace_ops = undef;

if(scalar @ARGV > 0) {
  if($ARGV[0] eq "-v") {
    shift;
    $trace_ops = 1;
  }
}

sub parse_input {
  my ($set_id) = @_;

  my $parts = {};

  my $results = Rebrickable::get_set_parts($set_id);

  if($results->{code} == 200 && defined $results->{data}) {

      foreach(@{$results->{data}->[0]->{parts}}) {
        my $e = $_;
        my $c = $e->{color_name};
        $c =~ s/\s/_/g;
        my $k = $e->{part_id}.$c;

        if(!defined $parts->{$k}) {
          $parts->{$k} = {part_id=>$e->{part_id},uid=>$e->{element_id},qty=>$e->{qty},type=>$e->{type},color=>$c,desc=>$e->{part_name}, hits=>1, sets=>[$set_id]};
        } else {
          $parts->{$k}->{qty} += $e->{qty};
          if($parts->{$k}->{type} ne $e->{type}) {
            $parts->{$k}->{type} .= ",$e->{type}";
          }
        }
      }
  }

  return $parts;
}

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

# Do all the operations

my @set_stack = ();

while(<>) {
  chomp;
  my $cmd = $_;

  # skip empty lines
  next if /^\s*$/;

  # skip comments
  next if /^\s*#.*$/;

  my $stack_size = scalar @set_stack;  
  print STDERR "$cmd ($stack_size)\n" if $trace_ops;

  if($cmd eq "union" ||
     $cmd eq "intersection" ||
     $cmd eq "difference" ||
     $cmd eq "sum") {
    # actually a valid two-operand command
    # pop the top two items from the stack
    # and if they are both valid, perform the op
    # then push the result back on the top of the stack
    my $b = pop @set_stack;
    my $a = pop @set_stack;

    if(defined $a && defined $b) {
      push @set_stack, do_op($cmd, $a, $b);
    } else {
      die "ERROR: Can't perform $cmd on stack with fewer than two items ($ARGV:$.).\n";
    }

  } elsif($cmd eq "dup") {
    # duplicates the top-most item on the stack
    my $a = pop @set_stack;
    if(defined $a) {
      push @set_stack, $a;
      push @set_stack, {%{$a}};
    } else {
      die "ERROR: Can't dup an empty stack ($ARGV:$.).\n";
    }
  
  } elsif($cmd eq "drop") {
    # drops the top-most item on the stack
    my $a = pop @set_stack;
    if(defined $a) {
      # great.  done
    } else {
      die "ERROR: Can't drop from an empty stack ($ARGV:$.).\n";
    }
  } elsif($cmd eq "exchange") {
    # exchanges the top two items on the stack
    my $b = pop @set_stack;
    my $a = pop @set_stack;
    if(defined $a && defined $b) {
      push @set_stack, $b;
      push @set_stack, $a;
    } else {
      die "ERROR: Can't exchange on a stack with fewer than two items ($ARGV:$.).\n";
    } 
  } elsif($cmd eq "print") {
    # display the set on the top of the stack
    my $a = pop @set_stack;
    if(defined $a) {
      print_set($a);
    } else {
      die "ERROR: Can't print from an empty stack ($ARGV:$.).\n";
    }
  } else {
    # must just be a set
    # parse it, and add it to the top of the stack
    my $a = parse_set($cmd);
    if(defined $a) {
      push @set_stack, $a;
    } else {
      die "ERROR: Can't load set [$cmd] onto the stack ($ARGV:$.).\n";
    }
  }
}

# if the stack isn't empty at the end, display the top item
if(scalar @set_stack) {
  my $stack_size = scalar @set_stack;
  print STDERR "[print] ($stack_size)\n" if $trace_ops;
  my $a = pop @set_stack;
  print_set($a);
}

exit 0

sub print_set {
  my ($a) = @_;

  foreach(sort keys %{$a}) {
    my $e=$a->{$_};
    if(defined $e && $e->{qty} > 0) {
      printf "%-10s %-10s %5d %6s %-20s \"%s\" %s\n", $e->{part_id}, $e->{uid},$e->{qty},$e->{type},$e->{color},$e->{desc}, join(',',@{$e->{sets}});
    }
  }

}

sub do_op {
  my ($op, $a, $b) = @_;

  my $c = {%{$a}};

  foreach(keys %{$b}) {
    my $k = $_;
    my $se = $b->{$k};
    my $pe = $c->{$k};

    # ok, if we don't find an exact match in the part_hash, check for related parts
    if(!defined $pe) {
      my @related = check_related($se->{part_id});
      my $color = $se->{color};

      RELATED: foreach(@related) {
        my $k2 = $_.$color;
        $pe = $c->{$k2};
        last RELATED if defined $pe;
      }
    }

    my $sq = $se->{qty};
    my $pq = defined $pe ? $pe->{qty} : 0;

    if($op eq "union") {
      if(!defined $pe) {
        # if the working set doesn't have this one, just use ours
        $c->{$k} = $se;
      } else {
        # if both have it, chose the max qty one to keep
        $pe->{qty} = $sq > $pq ? $sq : $pq;
        push @{$pe->{sets}}, $s;
      }

    } elsif($op eq "intersection") {
      if(!defined $pe) {
        # if the working set doesn't have this one, the intersection is 0
      } else {
        # if it does, choose the min and up the hit count
        $pe->{qty} = $sq < $pq ? $sq : $pq;
        $pe->{hits} += 1;
      }
    } elsif($op eq "difference") {
      if(!defined $pe) {
        # if the working set doesn't have this one, that's fine, leave it at 0
      } else {
        # if it does, remove our qty, bounded by 0 at the low side.
        $pe->{qty} = $pq > $sq ? ($pq-$sq) : 0;
      }
    } elsif($op eq "sum") {
      if(!defined $pe) {
        # if the working set doesn't have this one, just use ours
        $c->{$k} = $se;
      } else {
        # if it does, add our qty on to it
        $pe->{qty} += $sq;
        push @{$pe->{sets}}, $s;
      }
    } else {
      die "ERROR: Don't understand op [$op]\n";
    }
  }

  if($op eq "intersection") {
    my $desired_hits = 2;

    # now go back through everything in the working set.
    # if some part doesn't have a hit from everybody, somebody
    # must have had a 0, so set the qty to 0.
    foreach(keys %{$c}) {
      my $k = $_;
      my $pe = $c->{$k};
      my $ph = $pe->{hits};

      if($ph < $desired_hits) {
        # whoops somebody was missing this part
        $pe->{qty} = 0;
      }

      # reset the hits to 1 again, for next time
      $pe->{hits} = 1;
    }
  }

  return $c;
}

