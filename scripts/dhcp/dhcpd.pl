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

    #print Data::Dumper->Dump([$leases->getleasesbymac("68:5b:35:a3:6f:51")]);
    #print Data::Dumper->Dump([$leases->getleasesbymac("60:03:08:90:93:e8")]);
    #print Data::Dumper->Dump([$leases->getleasesbyip("10.255.0.108")]);
    #print Data::Dumper->Dump([$leases->getleasesbyip("10.255.0.210")]);
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
  $mqtt->run(
              "dhcp" => sub {
                           my ($topic, $message) = @_;
                           print ":: $topic :: $message\n";
                           my $decoded = $worker->{'json'}->decode($message);
                           if($decoded->{'action'} eq 'query'){
                             print "refreshing\n";
                             $worker->refresh;
                           }elsif($decoded->{'action'} eq 'commit'){
                             $worker->commit;
                           }
                           # exit 0;
                         },
              "#" => sub {
                           my ($topic, $message) = @_;
                           print "[$topic] $message\n";
                           # exit 0;
                         },
            );
}
callbacks
