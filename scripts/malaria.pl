#!/usr/bin/env perl
use LWP::UserAgent;
use Net::MQTT::Simple::SSL;
use JSON;
use Data::Dumper;
my $mqtt = Net::MQTT::Simple->new("127.0.0.1");
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

sub callbacks {
  $mqtt->run(
              "bikeshed/hue" => sub {
                                      my $saturation=255;
                                      my $ua = LWP::UserAgent->new;
                                      $ua->timeout(10);
                                      $ua->env_proxy;
                                      my ($topic, $message) = @_;

                                      my $decoded = decode_json($message);
                                      $action = $decoded->{'action'};
                                      $hue = $color->{$decoded->{'color'}};
                                      $light = $decoded->{'lights'};
                                      $saturation = 0 unless defined($hue);

                                      if($action == 'color'){
                                        foreach $light (@{$lights->{$light}}){
                                          my $json = JSON->new->allow_nonref;
                                          my $req = HTTP::Request->new( 'PUT', "http://philips-hue/api/jameswhite/lights/$light/state");
                                          $req->header( 'Content-Type' => 'application/json' );
                                          $req->content( $json->encode( { 'on' => $JSON::true, 'sat' => int($saturation), 'bri' => 255, 'hue' => int($hue) }) );
                                          my $lwp = LWP::UserAgent->new;
                                          my $response = $lwp->request( $req );
                                          # print STDERR Data::Dumper->Dump([$response->{'_content'}]);
                                        }
                                      }
                                      if($decoded->{'respond'}){
                                        ($respond_topic, $respond_host) = split(/@/,$decoded->{'respond'});
                                        print "respond to $respond_topic at $respond_host\n";
                                        $respond_host='127.0.0.1' unless defined($respond_host);
                                        my $response = Net::MQTT::Simple->new($respond_host);
                                        $mqtt->retain("$respond_topic" => "lights changed to $decoded->{'color'}");
                                      }
                                    },
              "#" => sub {
                           my ($topic, $message) = @_;
                           print "[$topic] $message\n";
                         },
            );
}
callbacks
