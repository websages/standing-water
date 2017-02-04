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

use Data::Dumper;
use JSON;
use Net::MQTT::Simple::SSL;

package DHCPWorker;
 use DHCPD;
 use File::Temp qw/ tempfile tempdir /;
 sub new {
   my $class = shift;
   my $self = {};
   bless $self, $class;
   $self->{'json'} = JSON->new->allow_nonref;
   $self->{'config'} = $self->refresh;
   return $self;
 }

sub config{
  my $self = shift;
  return $self->{'config'};
}

sub refresh {
    my $self = shift;
    # Scrape our leases
    my ($fh, $filename) = tempfile();
    system("/usr/bin/scp opt\@10.255.0.1:/var/db/dhcpd.leases $filename > /dev/null 2>&1");
    my $leases = DHCPD::Leases->new($filename);

    # Get our dhcpd.config
    system("/usr/bin/scp opt\@10.255.0.1:/etc/dhcpd.conf $filename > /dev/null 2>&1");
    $self->{'config'} = DHCPD::Config->new($filename);
    return $self->{'config'};

}

sub commit{
    my $self = shift;
    $pid = open(DHCPDCONF, "| /usr/bin/ssh opt\@10.255.0.1 'cat - | sudo tee /etc/dhcpd.conf'>/dev/null") or die "Couldn't fork: $!\n";
    print DHCPDCONF $self->{'config'}->text;
    close(DHCPDCONF) or warn "Couldn't close: $!\n";
    open (CHECKBOUNCE, "/usr/bin/ssh opt\@10.255.0.1 '/usr/bin/sudo /etc/rc.d/dhcpd restart'|");
    my $output=<CHECKBOUNCE>;
    close(CHECKBOUNCE);
    print $output;
}

1;

my $mqtt = Net::MQTT::Simple::SSL->new( "mqtt:8883",
                                        {
                                          SSL_ca_file   => "/etc/ssl/certs/mqtt-ca.crt",
                                          SSL_cert_file => "/etc/ssl/certs/localhost.crt",
                                          SSL_key_file  => "/etc/ssl/private/localhost.ckey",
                                         }
                                      );
sub callbacks {
  my $worker=DHCPWorker->new();

  # irc/room/soggies/nick/jameswhite/said
  # hubot/respond/room/bikeshed

  $mqtt->run(
              "dhcpd/create"   => sub {
                                        my ($topic, $message) = @_;
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
              "dhcpd/read"     => sub {
                                        my ($topic, $message) = @_;
                                        my $data = $worker->{'json'}->decode($message);
                                        print "refreshing\n";
                                        $worker->refresh;
                                        $data->{'action'} = 'read';
                                        $data->{'result'} = 'success';
                                        $mqtt->publish("dhcpd/response",$worker->{'json'}->encode($data));
                                      },
              "dhcpd/delete"   => sub {
                                        my ($topic, $message) = @_;
                                        my $data = $worker->{'json'}->decode($message);
                                        foreach my $requirement ('hostname'){
                                          unless(defined($data->{$requirement})){
                                            print "Requirement Missing: ".join(/, /,qw(hostname));
                                          }
                                        }
                                        if(defined($worker->config->getsubnetbyhost($data->{'hostname'}))){
                                            my $result=$worker->config->getsubnetbyhost($data->{'hostname'})->del_host($data->{'hostname'});
                                        }
                                        $data->{'action'} = 'delete';
                                        if($result){
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
