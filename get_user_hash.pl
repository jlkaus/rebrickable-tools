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

my $results = Rebrickable::call_api("get_user_hash","POST",{email=>$user, pass=>$pass}, $verbose);
if($results->{code} == 200) {
  Rebrickable::saveHash($results->{raw_data});
} else {
  die "ERROR: get_user_hash API got rc=$results->{code} [$results->{message}]\n";
}

exit 0;

