#!/usr/bin/env perl
BEGIN { unshift @INC, "../lib"; }
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use Net::MQTT::Simple::SSL;

my $mqtt_host='mqtt.hq.thebikeshed.io';
my $brain = {};
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
               "irc/room/#" => sub {
                                      my ($topic, $message) = @_;
                                      @parts=split(/\//,$topic);
                                      $who = $parts[4];
                                      $where = $parts[2];
                                      if($message =~m/\s*is it hot in here?/){
                                        open (PROC,"/bin/bash -c '(cd /var/cache/git/veralite; /usr/local/bin/bundle exec bin/temperature.rb)'|");
                                        while(my $line=<PROC>){
                                          chomp($line);
                                          $mqtt->publish("hubot/respond/room/$where" => "$who: $line")
                                        }
                                      }
                                   }
            );
}
callbacks
