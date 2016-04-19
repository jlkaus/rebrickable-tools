#!/usr/bin/perl

use strict;
use warnings;
use Rebrickable;

my $verbose = shift;

print "User email: ";
my $user = <stdin>;

print "Password: ";
system("stty -echo");
my $pass = <stdin>;
system("stty echo");
print "\n";

chomp $user;
chomp $pass;

my $results = Rebrickable::get_user_hash($user, $pass, $verbose);
if($results->{code} != 200) {
  die "ERROR: get_user_hash API got rc=$results->{code} [$results->{message}]\n";
}

exit 0;

