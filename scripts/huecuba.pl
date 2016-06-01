#!/usr/bin/env perl
use LWP::UserAgent;
use Net::MQTT::Simple;
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
               'all'     => [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 11,12 ],
               'one'     => [ 1 ], # closet
               'two'     => [ 2 ], # bedroom
               'three'   => [ 3 ], # living room
               'four'    => [ 4 ], # window (north)
               'five'    => [ 5 ], # window (south)
               'six'     => [ 6 ], # hall1
               'seven'   => [ 7 ], # hall2
               'eight'   => [ 8 ], # bath (middle)
               'nine'    => [ 9 ], # laundry
               'ten'     => [ 10 ], # DEAD
               'eleven'  => [ 11 ], # bath (left)
               'twelve'  => [ 12 ], # bath (right)
               'hall'    => [ 6,7 ], # hallway
               'windows' => [ 4, 5 ],
               'lamps'   => [ 1, 2 ],
               'bath'    => [ 8, 11, 12]
             };

sub callbacks {
  $mqtt->run(
              "hecuba/hue" => sub {
                                      my $saturation=255;
                                      my $ua = LWP::UserAgent->new;
                                      $ua->timeout(10);
                                      $ua->env_proxy;
                                      my ($topic, $message) = @_;

                                      my $decoded = decode_json($message);
                                      $action = $decoded->{'action'};
                                      $effect = $decoded->{'effect'};
                                      $alert = $decoded->{'alert'};
                                      $hue = $color->{$decoded->{'color'}};
                                      $light = $decoded->{'lights'};
                                      $saturation = 0 unless defined($hue);
                                      my @responses;

                                      if($action eq 'color'){
                                       foreach $light (@{$lights->{$light}}){
                                          $json_hashref = { 'on' => $JSON::true, 'sat' => int($saturation), 'bri' => 255, 'hue' => int($hue) };
                                          if($decoded->{'color'} eq 'black'){  $json_hashref->{'on'} = $JSON::false; }
                                          if(defined($alert)){
                                            $json_hashref->{'alert'} = $alert; 
                                          }

                                          my $json = JSON->new->allow_nonref;
                                          my $req = HTTP::Request->new( 'PUT', "http://10.255.3.77/api/jameswhite/lights/$light/state");
                                          $req->header( 'Content-Type' => 'application/json' );
                                          $req->content( $json->encode( $json_hashref ) );
                                          my $lwp = LWP::UserAgent->new;
                                          my $response = $lwp->request( $req );
                                          push(@responses,$response->{'_content'});
                                        }
                                      }elsif($action eq 'effect'){
                                        foreach $light (@{$lights->{$light}}){
                                          my $json = JSON->new->allow_nonref;
                                          my $req = HTTP::Request->new( 'PUT', "http://10.255.3.77/api/jameswhite/lights/$light/state");
                                          $req->header( 'Content-Type' => 'application/json' );
                                          $req->content( $json->encode( { 'effect' => $effect }) );
                                          my $lwp = LWP::UserAgent->new;
                                          my $response = $lwp->request( $req );
                                          push(@responses,$response->{'_content'});
                                        }
                                      }
                                      if($decoded->{'respond'}){
                                        ($respond_topic, $respond_host) = split(/@/,$decoded->{'respond'});
                                        print "respond to $respond_topic at $respond_host\n";
                                        $respond_host='127.0.0.1' unless defined($respond_host);
                                        my $mqtt = Net::MQTT::Simple->new($respond_host);
                                        $mqtt->retain("$respond_topic" => "\n".join("\n",@responses));
                                      }
                                    },
#              "#" => sub {
#                           my ($topic, $message) = @_;
#                           print "[$topic] $message\n";
#                         },
            );
}
callbacks
