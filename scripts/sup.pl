#!/usr/bin/env perl
BEGIN { unshift @INC, "../lib"; }
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use Net::MQTT::Simple::SSL;

my $mqtt_host='mqtt.hq.thebikeshed.io';
my $tlsopts= {
               SSL_ca_file       => '/etc/ssl/certs/ca.crt',
               SSL_cert_file     => '/etc/ssl/certs/localhost.crt',
               SSL_key_file      => '/etc/ssl/private/localhost.ckey',
               SSL_verifycn_name => $mqtt_host,
             };

my $mqtt = Net::MQTT::Simple::SSL->new( $mqtt_host, $tlsopts );

sub mqttsay{
  my ($where, $who, $what) = @_;
  print "$where <$who>: $what\n";
  my $mqtt_response = Net::MQTT::Simple::SSL->new( $respond_host, $tlsopts);
  $mqtt_response->publish("irc/room/$where/nick/crunchy/say" => "$what");
}

sub callbacks {
  $mqtt->run( "irc/room/+/nick/+/said" => sub {
                                                my ($topic, $message) = @_;
                                                if( $topic =~ /irc\/room\/(.*)\/nick\/(.*)\/said/){
                                                  my ($where, $who) = ($1, $2);
                                                  my $what = $message;
                                                  actions($where, $who, $what);
                                                }
                                               }
            );
}

sub actions {
  my ($where, $who, $what) = @_;
  for ( $what ) {
    /^sup?/ && do { mqttsay($where, $who, "not much."); last; };
  }
}

callbacks
