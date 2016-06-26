#!/usr/bin/env perl
use Net::MQTT::Simple::SSL;
use JSON;
use Data::Dumper;
my $mqtt = Net::MQTT::Simple::SSL->new( "mqtt:8883",
                                        {
                                          SSL_ca_file   => '/etc/ssl/certs/ca.crt',
                                          SSL_cert_file => '/etc/ssl/certs/localhost.crt',
                                          SSL_key_file  => '/etc/ssl/private/localhost.ckey',
                                         }
                                      );
sub callbacks {
  $mqtt->retain("perl test" => "hello world");
  $mqtt->run(
              "#" => sub {
                           my ($topic, $message) = @_;
                           print "[$topic] $message\n";
                           # exit 0;
                         },
            );
}
callbacks
