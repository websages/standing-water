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
use DHCPD;
use File::Temp qw/ tempfile tempdir /;
use Data::Dumper;
my ($fh, $filename) = tempfile();
# system("/usr/bin/scp opt\@10.255.0.1:/var/db/dhcpd.leases $filename");
# my $leases = DHCPLeases->new($filename);
# # print $leases->table;
# print Data::Dumper->Dump([$leases->getleasesbymac("60:03:08:90:93:e8")]);
# print Data::Dumper->Dump([$leases->getleasesbymac("68:5b:35:a3:6f:51")]);
# print Data::Dumper->Dump([$leases->getleasesbyip("10.255.0.108")]);
# print Data::Dumper->Dump([$leases->getleasesbyip("10.255.0.120")]);

system("/usr/bin/scp opt\@10.255.0.1:/etc/dhcpd.conf $filename >/dev/null 2>&1");
my $config = DHCPD::Config->new($filename);
#print Data::Dumper->Dump([$config->gethostbyip('10.255.13.52')]);
#print Data::Dumper->Dump([$config->gethostbymac('00:0c:29:82:79:0b')]);
#print Data::Dumper->Dump([$config->gethostbyname('newton')]);
#print Data::Dumper->Dump([$config->getallips]);

#foreach my $subnet (@{$config->subnets}){
#    print Data::Dumper->Dump([$subnet->next_available_ip]);
#}

if(defined($config->getsubnetbycidr("10.255.13.0/24"))){
    $config->getsubnetbycidr("10.255.13.0/24")->add_host('fermi','00:50:56:a4:e5:01');
}
print $config->text."\n";
if(defined($config->getsubnetbycidr("10.255.13.0/24"))){
    $config->getsubnetbycidr("10.255.13.0/24")->del_host('fermi');
}
print $config->text."\n";
