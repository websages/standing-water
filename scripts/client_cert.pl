#!/usr/bin/env perl
use Net::MQTT::Simple::SSL;
use JSON;
use Data::Dumper;
my $mqtt = Net::MQTT::Simple::SSL->new( "mqtt:8883",
                                        {
                                          SSL_ca_file   => '/etc/ssl/ca.crt',
                                          SSL_cert_file => '/etc/ssl/localhost.crt',
                                          SSL_key_file  => '/etc/ssl/localhost.ckey',
                                         }
                                      );
sub callbacks {
  $mqtt->retain("perl test" => "hello world");
  $mqtt->run(
              "perl test" => sub {
                           my ($topic, $message) = @_;
                           print "[$topic] $message\n";
                           exit 0;
                         },
            );
}
callbacks
