#!/usr/bin/env perl
BEGIN { unshift @INC, "../lib"; }
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use Net::MQTT::Simple::SSL;

my $mqtt_host='mqtt.hq.thebikeshed.io';
my $hue_host='10.255.0.224';
my $user='jameswhite';
$json = JSON->new->allow_nonref;
my $mqtt = Net::MQTT::Simple::SSL->new(
                                        $mqtt_host,
                                        {
                                          SSL_ca_file   => '/etc/ssl/certs/ca.crt',
                                          SSL_cert_file => '/etc/ssl/certs/localhost.crt',
                                          SSL_key_file  => '/etc/ssl/private/localhost.ckey',
                                         }
                                      );
sub callbacks {
  $mqtt->run(
              "owntracks/#" => sub {
                                      my ($topic, $message) = @_;
                                      my $data = $json->decode($message);

                                      my @parts = split(/\//,$topic);
                                      shift(@parts);
                                      unshift(@parts,"whereis");
                                      my $newtopic = join('/',@parts);

                                      my ($new_data,$lon,$lat);
                                      if( ref($data) eq 'HASH'){
                                          $lat = int($data->{'lat'} * 10000000)/10000000;
                                          $lon = int($data->{'lon'} * 10000000)/10000000;
                                      }
                                      if( ref($data) eq 'ARRAY'){
                                          $lat = int($data->[0]->{'lat'}*10000000)/10000000;
                                          $lon = int($data->[0]->{'lon'}*10000000)/10000000;
                                      }
                                      if($lon < 0){ $lon = abs($lon)."W"; }else{$lon = $lon."E"}
                                      if($lat < 0){ $lat = abs($lat)."S"; }else{$lat = $lat."N"}
                                      $new_data = $json->encode( { 'url' => "https://maps.google.com/?q=$lat,$lon" } );
                                      $mqtt->retain($newtopic => $new_data);
                                   },
            );
}
callbacks
