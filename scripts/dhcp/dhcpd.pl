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
use DHCPD;
use File::Temp qw/ tempfile tempdir /;

# Scrape our leases
my ($fh, $filename) = tempfile();
system("/usr/bin/scp opt\@10.255.0.1:/var/db/dhcpd.leases $filename");
my $leases = DHCPD::Leases->new($filename);

# Get our dhcpd.config
system("/usr/bin/scp opt\@10.255.0.1:/etc/dhcpd.conf $filename");
my $config = DHCPD::Config->new($filename);

print Data::Dumper->Dump([$leases->getleasesbymac("68:5b:35:a3:6f:51")]);
print Data::Dumper->Dump([$leases->getleasesbymac("60:03:08:90:93:e8")]);
print Data::Dumper->Dump([$leases->getleasesbyip("10.255.0.108")]);
print Data::Dumper->Dump([$leases->getleasesbyip("10.255.0.210")]);

# print $fh $config->text;

my $mqtt = Net::MQTT::Simple::SSL->new( "mqtt:8883",
                                        {
                                          SSL_ca_file   => '/etc/ssl/certs/ca.crt',
                                          SSL_cert_file => '/etc/ssl/certs/localhost.crt',
                                          SSL_key_file  => '/etc/ssl/private/localhost.ckey',
                                         }
                                      );
sub callbacks {
  $mqtt->run(
              "#" => sub {
                           my ($topic, $message) = @_;
                           print "[$topic] $message\n";
                           # exit 0;
                         },
            );
}
callbacks
