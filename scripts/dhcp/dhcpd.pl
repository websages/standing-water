#!/usr/bin/env perl
################################################################################
BEGIN {
  # we should use local::lib instead of this:
  use Cwd;
  use File::Basename /basename/;
  my $oldpwd = getcwd;
  my $here = dirname $0;
  chdir $here."/lib"; my $cwd = getcwd; push @INC, "$cwd";
  chdir $oldpwd;
}
################################################################################
# http://standards-oui.ieee.org/oui/oui.txt
use DHCPD;
use Net::MQTT::Simple::SSL;
my $mqtt = Net::MQTT::Simple::SSL->new( "mqtt:8883",
                                        {
                                          SSL_ca_file   => "/etc/ssl/certs/mqtt-ca.crt",
                                          SSL_cert_file => "/etc/ssl/certs/localhost.crt",
                                          SSL_key_file  => "/etc/ssl/private/localhost.ckey",
                                         }
                                      );
sub callbacks {
  my $worker=DHCPD::Worker->new();

  $mqtt->run(
              "dhcpd/create"   => sub {
                                        my ($topic, $message) = @_;
                                        print "[$topic] $message\n";
                                        my $data = $worker->{'json'}->decode($message);
                                        foreach my $requirement ('cidr','hostname','macaddr'){
                                          unless(defined($data->{$requirement})){
                                            print "Requirement Missing: ".join(/, /,qw(cidr,hostname,macaddr));
                                          }
                                        }
                                        if(defined($worker->config->getsubnetbycidr($data->{'cidr'}))){
                                            $worker->config->getsubnetbycidr($data->{'cidr'})->add_host($data->{'hostname'},$data->{'macaddr'});
                                        }
                                        $worker->commit;
                                        $worker->refresh;
                                        $data->{'action'} = 'create';
                                        $data->{'result'} = 'success';
                                        $mqtt->publish("dhcpd/response",$worker->{'json'}->encode($data));
                                      },
              "dhcpd/info"     => sub {
                                        my ($topic, $message) = @_;
                                        print "[$topic] $message\n";
                                        $data->{'action'} = 'info';
                                        my $data = $worker->{'json'}->decode($message);
                                        if(!defined($data->{'hostname'}) && !defined($data->{'macaddr'}) && !defined($data->{'ipaddress'}) ){
                                           $data->{'result'} = 'failure';
                                           $data->{'reason'} = 'Neither hostname, macaddr, nor ipaddress specified.';
                                           $mqtt->publish("dhcpd/response",$worker->{'json'}->encode($data));
                                           return;
                                        }
                                        print "refreshing\n";
                                        $worker->refresh;
                                        $data->{'action'} = 'info';
                                        $data->{'result'} = 'success';
                                        if(defined($data->{'hostname'})){
                                          $host = $worker->config->gethostbyname($data->{'hostname'});
                                          print Data::Dumper->Dump([$host]);
                                        }elsif(defined($data->{'macaddr'})){
                                          $host = $worker->config->gethostbymac($data->{'macaddr'});
                                          print Data::Dumper->Dump([$host]);
                                        }elsif(defined($data->{'ipaddress'})){
                                          $host = $worker->config->gethostbyip($data->{'ipaddress'});
                                          print Data::Dumper->Dump([$host]);
                                        }
                                        $mqtt->publish("dhcpd/response",$worker->{'json'}->encode($data));
                                      },
              "dhcpd/delete"   => sub {
                                        my ($topic, $message) = @_;
                                        print "[$topic] $message\n";
                                        my $data = $worker->{'json'}->decode($message);
                                        foreach my $requirement ('hostname'){
                                          unless(defined($data->{$requirement})){
                                            print "Requirement Missing: ".join(/, /,qw(hostname));
                                          }
                                        }
                                        my $result=0;
                                        if(defined($worker->config->getsubnetbyhost($data->{'hostname'}))){
                                            $result=$worker->config->getsubnetbyhost($data->{'hostname'})->del_host($data->{'hostname'});
                                        }
                                        $data->{'action'} = 'delete';
                                        if($result == 1){
                                          $worker->commit;
                                          $worker->refresh;
                                          $data->{'result'} = 'success';
                                        }else{
                                          $data->{'result'} = 'FAILED';
                                        }
                                        $mqtt->publish("dhcpd/response",$worker->{'json'}->encode($data));
                                      },
                      "#"      => sub {
                                        my ($topic, $message) = @_;
                                        print "[$topic] $message\n";
                                        # exit 0;
                                      },
            );
}
callbacks
