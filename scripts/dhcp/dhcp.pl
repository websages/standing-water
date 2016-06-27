#!/usr/bin/env perl
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
    return 1;
  }
  return 0;
}
1;

package DHCPLeases;
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
        my $lease = DHCPlease->new($text_chunk);
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

1;

package DHCPDSubnet;
  sub new{
    my $class = shift;
    my $blob = shift;
    my $self = {};
    bless $self, $class;

    return $self;
  }
1;

package DHCPDSubnetHost;
  sub new{
    my $class = shift;
    my $subnet = shift;
    my $self = {};
    return bless $self, $class;
  }
1;

package DHCPDConfig;
  use Data::Dumper;
  sub new {
    my $class = shift;
    my $filename = shift;
    my $self = {};
    bless $self, $class;
    $self->{'global-options'} = [];
    $self->{'subnets'} = [];
    if(-e $filename){
      open(my $dhcpdconf, "$filename") || die "cannot get config. $!";
      while(chomp(my $line=<$dhcpdconf>)){
       $self->{'config'}.=$line."\n";
     }
   }
   $self->parse_config;
   return $self;
  }

  sub balanced{
    my $self = shift;
    my $string = shift;
    my $left_braces = 0;
    my $right_braces = 0;
    my @strarray = split(//,$string);
    foreach my $char (@strarray){
      if($char eq '{'){ $left_braces++; }
      if($char eq '}'){ $right_braces++; }
    }
    if($left_braces == $right_braces){return 1;}
    return 0;
  }

  # My God forgive me for this subroutine.
  sub parse_config{
    my $self = shift;
    my @comments;
    my @config;
    my @tmpconfig = split(/\n/,$self->config);
    foreach my $line (split(/\n/,$self->config)){
      my ($config_line, $comment_line);
      if($line=~m/(.*[^\\])(#.*)/  ){
        $config_line=$1;
        $comment_line=$2;
      }else{
        $config_line=$line;
        $comment_line='';
      }
      push(@config,$config_line);
      push(@comments,$comment_line);
    }
    my @working = ();
    while(@tmpconfig){
      my $item = shift(@tmpconfig);
      unless($item=~m/^\s*$/){
        push( @working, $item ) unless($item=~m/^\s*$/);
        # print ">>>> " . join('',@working) . "\n";
        if($self->balanced( join('',@working) ) == 1){
          my $blob = join('',@working);
          if($blob=~m/^\s*subnet\s+/){
            push(@{ $self->{'subnets'} }, DHCPDSubnet->new(join("\n",@working)));
            @working = ();
          }elsif($blob=~m/^\s*option\s+/){
            push(@{$self->{'global-options'}},join('',@working));
            @working = ();
          }else{
            print STDERR "WARNING: unhandled block:\n". join("\n",@working)."\n";
            @working = ();
          }
        }
      }
    }
  }

  sub config{
    my $self=shift;
    return $self->{'config'};
  }
1;

################################################################################
use File::Temp qw/ tempfile tempdir /;
my ($fh, $filename) = tempfile();
print "$filename\n";
system("/usr/bin/scp opt\@10.255.0.1:/var/db/dhcpd.leases $filename");
my $leases = DHCPLeases->new($filename);
#print $leases->table;

system("/usr/bin/scp opt\@10.255.0.1:/etc/dhcpd.conf $filename");
my $config = DHCPDConfig->new($filename);
# print $config->config;

#my $mqtt = Net::MQTT::Simple::SSL->new( "mqtt:8883",
#                                        {
#                                          SSL_ca_file   => '/etc/ssl/certs/ca.crt',
#                                          SSL_cert_file => '/etc/ssl/certs/localhost.crt',
#                                          SSL_key_file  => '/etc/ssl/private/localhost.ckey',
#                                         }
#                                      );
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
