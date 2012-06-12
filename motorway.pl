#!/usr/bin/perl -w
use strict;
use CGI;
use TrafficEngland::MotorwayFlow;
use JSON::XS;
use Data::Dumper;

my $cgi = CGI->new();
my $te = TrafficEngland::MotorwayFlow->new();

print $cgi->header('text/plain');
my $json = JSON::XS->new();
my $compact = defined($cgi->param('compact'));

if (defined($cgi->param('m')) || defined($cgi->param('m_id')))
{
  $te->get_flow_page();
  if (defined($cgi->param('m_id')))
  {
    $te->set_motorway_by_id($cgi->param('m_id'));
  }
  else
  {
    $te->set_motorway_by_name($cgi->param('m'));
  }
  $te->submit_form();
  my $direction;
  if (defined($direction = $cgi->param('direction')))
  {
    $te->decode_left(0) if ($direction == 2);
    $te->decode_right(0) if ($direction == 1);
  }
  $te->minimum_level($cgi->param('min_level')) if defined($cgi->param('min_level'));
  $te->compact(1) if ($compact);
  $te->whole_motorway();
  $te->set_all_info();
  $te->search();
  $json->pretty(1) unless ($compact);
  my $mway = $te->decode();
  print $json->encode($mway);
}
elsif (defined($cgi->param('get_list')))
{
  $te->get_flow_page();
  $json->pretty(1) unless defined($cgi->param('compact'));
  print $json->encode($te->motorway_list());
}
elsif (my $data = $cgi->param('keywords'))
{
  my $request = $json->decode($data);  
  $te->get_flow_page();
  $te->set_motorway_by_name($request->{'motorway'});
  $te->decode_left($request->{'decode_left'});
  $te->decode_right($request->{'decode_right'});
  $te->minimum_level($request->{'min_level'});
  $te->submit_form();
  $te->whole_motorway();
  $te->set_all_info();
  $te->search();
  my $mway = $te->decode();
  print $json->encode($mway);
}
else
{
  die "nothing to do\n";
}

