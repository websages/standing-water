#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use AppUtil::VMUtil;

$Util::script_version = "1.0";

sub create_hash;
sub get_macaddr;

my %field_values = ( 'vmname'  => 'vmname' );

my %opts = (
   'vmname' => {
      type => "=s",
      help => "The name of the virtual machine",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();

my @valid_properties;
my $filename;

Util::connect();
get_macaddr();
Util::disconnect();

sub get_macaddr {
   my $filename;
   my %filter_hash = create_hash(Opts::get_option('ipaddress'),
                              Opts::get_option('powerstatus'),
                              Opts::get_option('guestos'));

   my $macaddress = '';
   my $vm_views = VMUtils::get_vms ('VirtualMachine', Opts::get_option ('vmname'), %filter_hash);
   if ($vm_views) {
     foreach (@$vm_views) {
       my $vm_view = $_;
       foreach my $device (@{ $_->config->hardware->device }){
          $macaddress = $device->macAddress if(ref($device) eq 'VirtualPCNet32');
        }
    }
  }
  print $macaddress."\n";
}

sub create_hash {
   my ($ipaddress, $powerstatus, $guestos) = @_;
   my %filter_hash;
   if ($ipaddress) {
      $filter_hash{'guest.ipAddress'} = $ipaddress;
   }
   if ($powerstatus) {
      $filter_hash{'runtime.powerState'} = $powerstatus;
   }
   # bug 299213
   if ($guestos) {
      # bug 456626
      $filter_hash{'config.guestFullName'} = qr/^\Q$guestos\E$/i;
   }
   return %filter_hash;
}
