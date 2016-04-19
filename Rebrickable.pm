package Rebrickable;

use strict;
use warnings;
use LWP;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use URI::Escape;
use JSON;
use Data::Dumper;

our $API_URL="http://rebrickable.com/api";
our $API_KEY="04KAsdNiyk";
our $USER_HASH_FILE=".rebrickable_userhash";

our $USER_AGENT=LWP::UserAgent->new();
$USER_AGENT->agent("PerlRebrick/0.1");

our $USER_HASH = undef;

binmode(STDOUT, ":utf8");

sub saveHash {
  my ($hash) = @_;

  $USER_HASH = $hash;

  chomp $hash;
  my $ofh;
  open($ofh, ">", $USER_HASH_FILE) or die "ERROR: Can't open [$USER_HASH_FILE] for writing\n";
  print $ofh "$hash\n";
  close($ofh);
  chmod 0600, $USER_HASH_FILE;
}

sub loadHash {
  my $hash = undef;
  my $ifh;
  open($ifh, "<", $USER_HASH_FILE) or die "ERROR: Can't open [$USER_HASH_FILE] for reading\n";
  while(<$ifh>) {
    chomp;
    $hash = $_;
    last;
  }
  close($ifh);

  $USER_HASH = $hash;

  return $hash;
}

loadHash if -r $USER_HASH_FILE;

sub call_api {
  my ($api, $method, $parms, $verbose) = @_;
  my $results = {};

  $parms = {} if !defined $parms;

  if(defined $USER_HASH) {
    $parms->{hash} = $USER_HASH;
  }

  $parms->{key} = $API_KEY;
  $parms->{format} = "json";


  my $encoded_parms = "";
  foreach(keys %{$parms}) {
    my $p = $_;
    if(defined $parms->{$p}) {
      my $v = $parms->{$p};
      my $e_v = uri_escape($v);

      if($encoded_parms eq "") {
        $encoded_parms = "$p=$e_v";
      } else {
        $encoded_parms .= "&$p=$e_v";
      }
    }
  }


  my $req = undef;
  if($method eq "GET") {

    $req = HTTP::Request->new(GET => "$API_URL/$api?$encoded_parms");
    $req->header(Accept=>"application/json");

  } elsif($method eq "POST") {

    $req = HTTP::Request->new(POST => "$API_URL/$api");
    $req->content_type("application/x-www-form-urlencoded");
    $req->header(Accept=>"application/json");

    $req->content($encoded_parms);

  } else {
    die "ERROR: Unknown method [$method] used for api [$api]\n";
  }

  if($verbose) {
    print "REQ:\n";
    print $req->as_string;
    print "\n\n";
  }

  my $rsp = $USER_AGENT->request($req);

  if($verbose) {
    print "RSP:\n";
    print $rsp->as_string;
    print "\n\n";
  }

  if($rsp->header("Content-type") =~ /\bapplication\/json\b/) {
    $results->{data} = JSON::decode_json($rsp->decoded_content());
    if($verbose) {
      print Data::Dumper->Dump([$results->{data}],["data"]);
    }
  }

  $results->{code} = $rsp->code;
  $results->{raw_data} = $rsp->decoded_content();
  $results->{message} = $rsp->message;

  return $results;
}

sub get_user_hash {
  my ($email, $pass, $verbose) = @_;

  my $results = call_api("get_user_hash","POST", {email=>$email, pass=>$pass}, $verbose);
  if($results->{code} == 200) {
    saveHash($results->{raw_data});
  }

  return $results;
}

sub get_user_set_lists {
  my ($verbose) = @_;

  return  call_api("get_user_setlists","GET",{},$verbose);
}

sub get_user_sets {
  my ($setlist_id, $verbose) = @_;

  return call_api("get_user_sets","GET",{setlist_id=>$setlist_id}, $verbose);
}

sub get_set_parts {
  my ($set_id, $verbose) = @_;

  return call_api("get_set_parts","GET",{set=>$set_id}, $verbose);
}

sub get_part {
  my ($part_id, $verbose) = @_;

  return call_api("get_part","GET",{part_id=>$part_id,inc_rels=>1}, $verbose);
}

1;

