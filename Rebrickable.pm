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
use File::Path;
use Time::HiRes;
use POSIX;

our $API_URL="http://rebrickable.com/api";
our $API_KEY="04KAsdNiyk";
our $API_BACKOFF_TIME=1.0;

our $CACHE_DIR=glob("~/.cache/rebrickable");
our $USER_HASH_FILE=glob("~/.rebrickable_userhash");

our $USER_AGENT=LWP::UserAgent->new();
$USER_AGENT->agent("PerlRebrick/0.1");

our $USER_HASH = undef;

our $VERBOSITY = 0;


sub trace {
  my ($level, $msg) = @_;

  if($VERBOSITY >= $level) {
    print "[".POSIX::strftime("%Y-%m-%d %H:%M:%SZ", gmtime)."] ($level) $msg\n";
  }
}

binmode(STDOUT, ":utf8");

File::Path::make_path($CACHE_DIR);
die "ERROR: Can't create cache directory [$CACHE_DIR] or it already exists but isn't a directory.\n" if !-d $CACHE_DIR;

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

our $LAST_API_CALL = 0.0;

sub call_api {
  my ($api, $method, $parmsi) = @_;
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

  my $now = Time::HiRes::time();
  if($now - $LAST_API_CALL < $API_BACKOFF_TIME) {
    # too quick, so sleep a bit
    trace(1, "Throttling...");
    Time::HiRes::sleep($API_BACKOFF_TIME - ($now - $LAST_API_CALL));
  }

  trace(2, "REQ: ".$req->as_string);

  trace(1, "$method $API_URL/$api?$encoded_parms");

  $LAST_API_CALL = Time::HiRes::time();
  my $rsp = $USER_AGENT->request($req);
  trace(1, $rsp->code . " [".$rsp->message."]");

  trace(2, "RSP: ".$rsp->as_string);

  if($rsp->header("Content-type") =~ /\bapplication\/json\b/) {
    $results->{data} = JSON::decode_json($rsp->decoded_content());
    trace(3, Data::Dumper->Dump([$results->{data}],["data"]));
  }

  $results->{code} = $rsp->code;
  $results->{raw_data} = $rsp->decoded_content();
  $results->{message} = $rsp->message;

  return $results;
}

sub get_user_hash {
  my ($email, $pass) = @_;

  my $results = call_api("get_user_hash","POST", {email=>$email, pass=>$pass});
  if($results->{code} == 200) {
    saveHash($results->{raw_data});
  }

  return $results;
}

sub get_user_setlists {
  return  call_api("get_user_setlists","GET",{});
}

sub get_user_sets {
  my ($setlist_id) = @_;

  return call_api("get_user_sets","GET",{setlist_id=>$setlist_id});
}

sub get_set_parts {
  my ($set_id) = @_;

  return call_api("get_set_parts","GET",{set=>$set_id});
}

sub get_part {
  my ($part_id) = @_;

  return call_api("get_part","GET",{part_id=>$part_id,inc_rels=>1});
}

sub get_set {
  my ($set_id) = @_;

  return call_api("get_set","GET",{set_id=>$set_id});
}

sub get_user_part_lists {
  return call_api("get_user_part_lists","GET",{});
}

sub get_user_parts {
  my ($partlist_id) = @_;

  return call_api("get_user_parts","GET",{partlist_id=>$partlist_id});
}

our $HAVE_LOADED_PART_CACHE = undef;
our $HAVE_LOADED_SET_CACHE = undef;
our $HAVE_LOADED_SET_PARTS_CACHE = undef;
our $HAVE_LOADED_COLOR_CACHE = undef;
our %part_cache = ();
our %set_cache = ();
our %set_parts_cache = ();
our %color_cache = ();

# caching method for part retrievals
sub part_lookup {
  my ($part_id) = @_;

  load_part_cache() if !defined $HAVE_LOADED_PART_CACHE;

  if(!defined $part_cache{$part_id}) {
    my $results = get_part($part_id);

    # check results status to make sure it worked

    # save off the interesting bits to the cache
    # $part_cache{$part_id} = 
  }

  return $part_cache{$part_id};
}

# caching method for set retrievals
sub set_lookup {
  my ($set_id) = @_;

  load_set_cache() if !defined $HAVE_LOADED_SET_CACHE;

  if(!defined $set_cache{$set_id}) {
    my $results = get_set($set_id);

    # check results status to make sure it worked

    # save off the interesting bits to the cache
    # $set_cache{$set_id} = 
  }

  return $set_cache{$set_id};
}

# caching method for set parts retrievals
sub set_parts_lookup {
  my ($set_id) = @_;

  load_set_parts_cache() if !defined $HAVE_LOADED_SET_PARTS_CACHE;

  if(!defined $set_parts_cache{$set_id}) {
    my $results = get_set_parts($set_id);

    # check results status to make sure it worked

    # save off the interesting bits to the cache
    # $set_parts_cache{$set_id} = 
  }

  return $set_parts_cache{$set_id};
}

# caching method for color retrievals
sub color_lookup {
  my ($color_id) = @_;

  load_color_cache() if !defined $HAVE_LOADED_COLOR_CACHE;

  if(!defined $color_cache{$color_id}) {
    my $results = get_colors();

    # check results status to make sure it worked

    # save off the interesting bits to the cache
    # $color_cache{$color_id} = 
  }

  return $color_cache{$color_id};
}

# method to load the part cache (called on first retrieval)
sub load_part_cache {
  return if defined $HAVE_LOADED_PART_CACHE;


  $HAVE_LOADED_PART_CACHE = 1;
}

# method to load the set cache (called on first retrieval)
sub load_set_cache {
  return if defined $HAVE_LOADED_SET_CACHE;


  $HAVE_LOADED_SET_CACHE = 1;
}

# method to load the set parts cache (called on first retrieval)
sub load_set_parts_cache {
  return if defined $HAVE_LOADED_SET_PARTS_CACHE;



  $HAVE_LOADED_SET_PARTS_CACHE = 1;
}

# method to load the color cache (called on first retrieval)
sub load_color_cache {
  return if defined $HAVE_LOADED_COLOR_CACHE;



  $HAVE_LOADED_COLOR_CACHE = 1;
}

# method to save the part cache (called on exit, if it was loaded)
sub save_part_cache {
  return if !defined $HAVE_LOADED_PART_CACHE;



}

# method to save the set cache (called on exit, if it was loaded)
sub save_set_cache {
  return if !defined $HAVE_LOADED_SET_CACHE;



}

# method to save the set parts cache (called on exit, if it was loaded)
sub save_set_parts_cache {
  return if !defined $HAVE_LOADED_SET_PARTS_CACHE;



}

# method to save the color cache (called on exit, if it was loaded)
sub save_color_cache {
  return if !defined $HAVE_LOADED_COLOR_CACHE;



}

EXIT {
  save_part_cache() if $HAVE_LOADED_PART_CACHE;
  save_set_cache() if $HAVE_LOADED_SET_CACHE;
  save_set_parts_cache() if $HAVE_LOADED_SET_PARTS_CACHE;
}

1;

