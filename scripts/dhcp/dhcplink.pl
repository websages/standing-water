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
my $json = JSON->new->allow_nonref;
sub callbacks {
  my $macaddr="00:50:56:a4:e5:01";
  $mqtt->publish("dhcpd/info" => $json->encode({ 'macaddr' => $macaddr }));
  $mqtt->run(
              "dhcpd/response" => sub {
                                        my ($topic, $message) = @_;
                                        # print "[$topic] $message\n";
                                        my $data = $json->decode($message);
                                        if( ($data->{'result'} eq 'success') && ($data->{'macaddr'} eq  $macaddr) ){
                                          print "{\"macaddr\":\"$data->{'macaddr'}\", \"hostname\":\"$data->{'hostname'}\",\"domain\":\"$data->{'domain'}\",\"ipaddress\":\"$data->{'ipaddress'}\"}\n";
                                          exit 0;
                                        }else{
                                          print Data::Dumper->Dump([$data]);
                                          exit 0;
                                        }
                                      }
  );
}
callbacks
