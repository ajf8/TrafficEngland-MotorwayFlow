#!/usr/bin/perl -w
use strict;
use TrafficEngland::MotorwayFlow;
use Data::Dumper;
use JSON::XS;

my $te = TrafficEngland::MotorwayFlow->new();

$te->get_flow_page();
$te->set_motorway_by_name('M3');
$te->submit_form();
$te->whole_motorway();
$te->set_all_info();
$te->search();

my $mway = $te->decode();

my $json = JSON::XS->new();
$json->pretty(1);
print $json->encode($mway);
