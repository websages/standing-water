#!/usr/bin/env perl
BEGIN { unshift @INC, "../lib"; }
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use POE;
use Net::MQTT::Simple::SSL;

my $pki_opts= {
                SSL_ca_file   => '/etc/ssl/ca.crt',
                SSL_cert_file => '/etc/ssl/tyr.hq.thebikeshed.io.crt',
                SSL_key_file  => '/etc/ssl/tyr.hq.thebikeshed.io.ckey',
              };
my $mqtt = Net::MQTT::Simple::SSL->new( "planck:8883",
                                        {
                                          SSL_ca_file   => '/etc/ssl/ca.crt',
                                          SSL_cert_file => '/etc/ssl/tyr.hq.thebikeshed.io.crt',
                                          SSL_key_file  => '/etc/ssl/tyr.hq.thebikeshed.io.ckey',
                                         }
                                      );
# my $bridge = '10.255.3.77';
my $bridge = 'philips-hue';
my $user = 'jameswhite';
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


POE::Session->create(
    inline_states => {
      _start => sub {
                       $_[KERNEL]->yield("next");
                       $_[KERNEL]->yield("callbacks");
                    },
      next   => sub {
                      `say tick`;
                      $_[KERNEL]->delay(next => 1);
                    },
      callbacks   => \&callbacks,
    },
  );

POE::Kernel->run();
exit;
################################################################################
#
sub put_lights_state{
  my ($light, $json_hashref) = @_;
  my $json = JSON->new->allow_nonref;
  my $ua = LWP::UserAgent->new;
     $ua->timeout(10);
     $ua->env_proxy;
  my $req = HTTP::Request->new( 'PUT', "http://$bridge/api/$user/lights/$light/state");
     $req->header( 'Content-Type' => 'application/json' );
     $req->content( $json->encode( $json_hashref ) );
  my $response = $ua->request( $req );
  return $response->{'_content'};
}

sub callbacks {
  my ($self, $kernel, $heap, $sender, @args) = @_[OBJECT, KERNEL, HEAP, SENDER, ARG0 .. $#_];
  $mqtt->run(
              "hecuba/hue" => sub {
                                      my ($topic, $message) = @_;

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
                                          my $mqtt = Net::MQTT::Simple::SSL->new( "planck:8883",
                                                                                  {
                                                                                    SSL_ca_file   => '/etc/ssl/ca.crt',
                                                                                    SSL_cert_file => '/etc/ssl/tyr.hq.thebikeshed.io.crt',
                                                                                    SSL_key_file  => '/etc/ssl/tyr.hq.thebikeshed.io.ckey',
                                                                                   }
                                                                                );
                                          $mqtt->publish($topic => $message);
                                        }
                                        foreach $light (@{$lights->{$light}}){ push(@responses, put_lights_state($light,$json_hashref)); }
                                      }elsif($action eq 'effect'){
                                        foreach $light (@{$lights->{$light}}){ push(@responses, put_lights_state($light,{'effect' => $effect})); }
                                      }
                                      if($decoded->{'respond'}){
                                        ($respond_topic, $respond_host) = split(/@/,$decoded->{'respond'});
                                        print "respond to $respond_topic at $respond_host\n";
                                        $respond_host='127.0.0.1' unless defined($respond_host);
                                        my $mqtt = Net::MQTT::Simple::SSL->new( $respond_host,
                                                                                {
                                                                                  SSL_ca_file   => '/etc/ssl/ca.crt',
                                                                                  SSL_cert_file => '/etc/ssl/tyr.hq.thebikeshed.io.crt',
                                                                                  SSL_key_file  => '/etc/ssl/tyr.hq.thebikeshed.io.ckey',
                                                                                 }
                                                                              );
                                        $mqtt->retain("$respond_topic" => "\n".join("\n",@responses));
                                      }
                                    },
              "#" => sub {
                           my ($topic, $message) = @_;
                           print "[$topic] $message\n";
                         },
            );
}
