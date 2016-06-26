#!/usr/bin/env perl
BEGIN { unshift @INC, "../lib"; }
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use Net::MQTT::Simple::SSL;

my $mqtt_host='mqtt';
my $hue_host='10.255.0.224';
my $user='jameswhite';
my $mqtt = Net::MQTT::Simple::SSL->new(
                                        $mqtt_host,
                                        {
                                          SSL_ca_file   => '/etc/ssl/certs/ca.crt',
                                          SSL_cert_file => '/etc/ssl/certs/localhost.crt',
                                          SSL_key_file  => '/etc/ssl/private/localhost.ckey',
                                         }
                                      );
my $color  =  {
                'red'       => hex("0x0000"),
                'orange'    => hex("0x1800"),
                'yellow'    => hex("0x4000"),
                'green'     => hex("0x639C"),
                'cyan'      => hex("0x9000"),
                'blue'      => hex("0xB748"),
                'indigo'    => hex("0xC000"),
                'lavender'  => hex("0xD000"),
                'pink'      => hex("0xE000"),
              };
my $lights = {
               'all'   => [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ],
               'one'   => [ 1 ], # lamp next to the keg
               'two'   => [ 2 ], # lamp between fryman and rick
               'three' => [ 3 ], # lamp behind stephen
               'four'  => [ 4 ], # window_0 (to stephenyeargin's left)
               'five'  => [ 5 ], # window_2 (to jfryman's right)
               'six'   => [ 6 ], # window_4 (to aziz's left)
               'seven' => [ 7 ], # window_1 (to northrup's right)
               'eight' => [ 8 ], # window_5 (to jameswhite's right)
               'nine'  => [ 9 ], # window_3 (to rickbra's left)
               'jameswhite'  => [ 8 ], # (around jameswhite)
               'aziz'  => [ 6 ],# (around aziz)
               'rick'  => [ 9 ],# (around rick)
               'jfryman' => [ 5, 2 ],# (around jfryman)
               'northrup' => [ 7 ],# (around northrup)
               'stephen' => [ 4, 3 ],# (around stephen)
               'lamps' => [ 1, 2, 3 ],# standing lamps
               'windows' => [ 4, 5, 6, 7, 8, 9 ] # windows
             };

sub put_lights_state{
  my ($light, $json_hashref) = @_;
  my $json = JSON->new->allow_nonref;
  my $ua = LWP::UserAgent->new;
     $ua->timeout(10);
     $ua->env_proxy;
  print "http://$hue_host/api/$user/lights/$light/state\n";
  my $req = HTTP::Request->new( 'PUT', "http://$hue_host/api/$user/lights/$light/state");
     $req->header( 'Content-Type' => 'application/json' );
     $req->content( $json->encode( $json_hashref ) );
  my $response = $ua->request( $req );
  return $response->{'_content'};
}

sub callbacks {
  $mqtt->run(
              "bikeshed/hue" => sub {
                                      my ($topic, $message) = @_;
                                      print "[$topic] $message\n";
                                      my $saturation = 255;
                                      my $decoded = decode_json($message);
                                      $light      = $decoded->{'lights'};
                                      $action     = $decoded->{'action'};
                                      $effect     = $decoded->{'effect'};
                                      $hue        = $color->{$decoded->{'color'}};
                                      $saturation = 0 unless defined($hue);

                                      my @responses;
                                      if($action eq 'color'){
                                        $json_hashref = { 'on' => $JSON::true, 'sat' => int($saturation), 'bri' => 255, 'hue' => int($hue) };
                                        if($decoded->{'color'} eq 'black'){  $json_hashref->{'on'} = $JSON::false; }
                                        if(defined($decoded->{'alert'})){
                                          $json_hashref->{'alert'} = $decoded->{'alert'};
                                        }
                                        foreach $light (@{$lights->{$light}}){ push(@responses, put_lights_state($light,$json_hashref)); }
                                      }elsif($action eq 'effect'){
                                        foreach $light (@{$lights->{$light}}){ push(@responses, put_lights_state($light,{'effect' => $effect})); }
                                      }

                                      # Respond if respond_topic was given
                                      if($decoded->{'respond_topic'}){
                                        ($respond_topic, $respond_host) = split(/@/,$decoded->{'respond_topic'});
                                        print "respond to $respond_topic at $respond_host\n";
                                        $respond_host='mqtt' unless defined($respond_host);
                                        my $mqtt_response = Net::MQTT::Simple::SSL->new( $respond_host,
                                                                                {
                                                                                  SSL_ca_file   => '/etc/ssl/certs/ca.crt',
                                                                                  SSL_cert_file => '/etc/ssl/certs/localhost.crt',
                                                                                  SSL_key_file  => '/etc/ssl/private/localhost.ckey',
                                                                                 }
                                                                              );
                                        $mqtt_response->publish("$respond_topic" => "\n".join("\n",@responses));

                                      }
                                    },
              "#" => sub {
                           my ($topic, $message) = @_;
                           print "[$topic] $message\n";
                         },
            );
}
callbacks
