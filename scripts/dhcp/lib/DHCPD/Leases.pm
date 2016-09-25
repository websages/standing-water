package DHCPD::Leases;
use DHCPD::Lease;
use strict;
sub new($){
  my $class = shift;
  my $filename = shift;
  my $self={};
  bless $self, $class;

  $self->{'leases'} = {};
  my $text_chunk='';
  open(my $leasefile, "$filename") || die "cannot get leases. $!";
  while(chomp(my $line=<$leasefile>)){
    if($line=~m/^\s*lease .*/){
      if(! $text_chunk eq ""){
        my $lease = DHCPD::Lease->new($text_chunk);
        push(@{ $self->{'leases'}->{$lease->lease} },$lease);
        $text_chunk=$line;
      }else{
        $text_chunk.=$line;
      }
    }else{
      $text_chunk.=$line;
    }
  }
  return $self;
}

sub table{
   my $self = shift;
   my $table = Text::ASCIITable->new({ headingText => 'DHCP Leases' });
   $table->setCols('lease', 'hardware','starts','ends','abandoned');
   foreach my $key (sort(keys($self->{'leases'}))){
     my $latest_entry = undef;
     foreach my $entry (@{$self->{'leases'}->{$key}}){
       if( !defined($latest_entry) || ($entry->{'starts'} > $latest_entry->{'starts'}) ){
          $latest_entry = $entry;
       }
     }
     unless(defined($latest_entry->{'abandoned'})){
       $table->addRow($latest_entry->lease, $latest_entry->hardware,$latest_entry->starts,$latest_entry->ends,defined($latest_entry->{'abandoned'})?'yes':'no');
     }
   }
   return $table;
}

sub leases{
  my $self=shift;
  return $self->{'leases'}
}

sub getleasesbymac{
  my $self = shift;
  my $macaddr = shift;
  my @matches;
  foreach my $ip (keys($self->leases)){
    foreach my $entry ( @{$self->leases->{$ip}} ){
      push(@matches, $entry) if($entry->hardware eq $macaddr);
    }
  }
  return @matches
}

sub getleasesbyip{
  my $self = shift;
  my $ip = shift;
  return $self->leases->{$ip};
}


1;
