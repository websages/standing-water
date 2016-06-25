#!/usr/bin/env perl
use Net::MQTT::Simple::SSL;
use JSON;
use Data::Dumper;

package DHCPlease;
use Text::ASCIITable;
sub new {
  my $class = shift;
  my $self = {};
  my $self->{'blob'} = shift;
  if($self->{'blob'}=~m/lease\s+(.*)\s+{(.*)}/){
    $self->{'lease'} = $1;
    $self->{'data'} = $2;
    foreach my $entry (split(/;/,$self->{'data'})){
      $entry=~s/^\s+//;
      my @databits = split(/\s+/,$entry);
      my $key = shift(@databits);
      shift(@databits) if($databits[0] eq ethernet);
      shift(@databits) if($databits[0]=~m/^[0-9]{1}$/);
      $self->{$key}=join(' ',@databits);
    }
    delete $self->{'blob'};
    delete $self->{'data'};
  }else{
    print STDERR "error unknown format: $self->{'blob'}\n";
  }
  return bless $self, $class;
}

sub lease{
  my $self = shift;
  return $self->{'lease'};
}

sub hardware{
  my $self = shift;
  return $self->{'hardware'};
}

sub starts{
  my $self = shift;
  return $self->{'starts'};
}

sub ends{
  my $self = shift;
  return $self->{'ends'};
}

sub abandoned{
  my $self = shift;
  if(defined($self->{'abandoned'})){
    return true;
  }
  return false;
}
1;

package DHCPDEntry;
  sub new{
    my $class = shift;
    my $self = {};
    return bless $self, $class;
  }
1;

#my $mqtt = Net::MQTT::Simple::SSL->new( "mqtt:8883",
#                                        {
#                                          SSL_ca_file   => '/etc/ssl/certs/ca.crt',
#                                          SSL_cert_file => '/etc/ssl/certs/localhost.crt',
#                                          SSL_key_file  => '/etc/ssl/private/localhost.ckey',
#                                         }
#                                      );
sub leases {
   my $text_chunk='';
   my $leases = {};
   open(my $leasefile, "/usr/bin/ssh opt\@10.255.0.1 'cat /var/db/dhcpd.leases'|") || die "cannot get leases. $!";
   while(chomp(my $line=<$leasefile>)){
     if($line=~m/^\s*lease .*/){
       if(! $text_chunk eq ""){
         my $lease = DHCPlease->new($text_chunk);
         push(@{ $leases->{$lease->lease} },$lease);
         $text_chunk=$line;
       }else{
         $text_chunk.=$line;
       }
     }else{
       $text_chunk.=$line;
     }
   }
   my $table = Text::ASCIITable->new({ headingText => 'DHCP Leases' });
   $table->setCols('lease', 'hardware','starts','ends','abandoned');
   foreach my $key (sort(keys($leases))){
     my $latest_entry = undef;
     foreach my $entry (@{$leases->{$key}}){
       if( !defined($latest_entry) || ($entry->{'starts'} > $latest_entry->{'starts'}) ){
          $latest_entry = $entry;
       }
     }
     unless(defined($latest_entry->{'abandoned'})){
       $table->addRow($latest_entry->lease, $latest_entry->hardware,$latest_entry->starts,$latest_entry->ends,defined($latest_entry->{'abandoned'})?'yes':'no');
     }
   }
   print $table;
}
#sub callbacks {
#  $mqtt->retain("perl test" => "hello world");
#  $mqtt->run(
#              "#" => sub {
#                           my ($topic, $message) = @_;
#                           print "[$topic] $message\n";
#                           # exit 0;
#                         },
#            );
#}
#callbacks
leases
