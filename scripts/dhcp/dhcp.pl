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

package DHCPDSubnet;
  sub new{
    my $class = shift;
    my $blob = shift;
    my $self = {};
    bless $self, $class;
    $self->parse_subnet($blob);
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

  sub parse_subnet{
    my $self = shift;
    my $blob = shift;
    my @blobby = split(//,$blob);
    my @prefix = ();
    my @suffix= ();
    my @working= ();
    my $character='';
    while($character ne '{'){
      $character=shift(@blobby);
      push(@prefix,$character);
    }
    $character='';
    while($character ne '}'){
      $character=pop(@blobby);
      unshift(@suffix,$character);
    }
    my @tmpconfig = split(/\n/,join('', @blobby));
    while(@tmpconfig){
      my $item = shift(@tmpconfig);
      unless($item=~m/^\s*$/){
        push( @working, $item ) unless($item=~m/^\s*$/);
        # print ">>>> " . join('',@working) . "\n";
        if($self->balanced( join('',@working) ) == 1){
          my $blob = join('',@working);
          if($blob=~m/^\s*host\s+(.*)\s+{/){
            push(@{ $self->{'hosts'} }, DHCPDSubnetHost->new(join("\n",@working)));
            @working= ();
          }else{
            push(@{ $self->{'config'} },join('',@working));
            @working= ();
          }
        }
      }
    }
    map( { $_=~s/^\s+//; $_=~s/\s+$//; $_=~s/;$//; }  @{$self->{'config'}});
    return $self;
  }

  sub hosts{
    my $self=shift;
    return $self->{'hosts'};
  }

1;

package DHCPDSubnetHost;
  sub new{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my $blob = shift;
    my @blobby = split(//,$blob);
    my @prefix = ();
    my @suffix= ();

    my $character='';
    while($character ne '{'){
      $character=shift(@blobby);
      push(@prefix,$character);
    }
    $self->{'prefix'} = join('',@prefix);
    $self->{'prefix'} =~ s/^\s+//;
    $self->{'prefix'} =~ s/\s+$//;
    if($self->{'prefix'} =~ m/host\s+(\S+)\s+{/){ 
        $self->{'hostname'} = $1; 
        delete $self->{'prefix'};
    }
    

    $character='';
    while($character ne '}'){
      $character=pop(@blobby);
      unshift(@suffix,$character);
    }
    $self->{'suffix'} = join('',@suffix);
    $self->{'suffix'} =~ s/^\s+//;
    $self->{'suffix'} =~ s/\s+$//;
    if($self->{'suffix'} =~ m/}\s+#\s*(.*)/){ 
        $self->{'comment'} = $1; 
        delete $self->{'suffix'};
    }

    $self->{'block'} = join('', @blobby);
    $self->{'block'} =~ s/^\s+//;
    $self->{'block'} =~ s/\s+$//;
    $self->{'block'} =~ s/\n/ /;
    @{$self->{'items'}} = split(/;/,$self->{'block'});
    delete $self->{'block'};
    map( { $_=~s/^\s+//; $_=~s/\s+$//; }  @{$self->{'items'}});
    foreach my $item (@{ $self->{'items'} }){
        if($item =~ m/fixed-address\s+(\S+)/){ $self->{'ip'} = $1; }
        elsif($item =~ m/hardware\s+ethernet\s+(\S+)/){ $self->{'macaddr'} = $1; }
        elsif($item =~ m/option\s+(\S+)\s+(.*)/){ $self->{'option'}->{$1} = $2; }
        else{ print "I don't understand what [$item] is.\n"
    }
    delete $self->{'items'}};
    return $self;
  }

  sub text{
      my $self=shift;
      my $text = '';
      if(defined( $self->{'prefix'} )){
          $text = $self->{'prefix'};
      }else{
          $text = "host $self->{'hostname'} {";
      }

      if(defined( $self->{'items'} )){
          $text .= join(';',$self->{'items'});
      }else{
          $text .= " hardware ethernet $self->{'macaddr'};" if(defined($self->{'macaddr'}));
          $text .= " fixed-address $self->{'ip'};" if(defined($self->{'ip'}));
          if(defined($self->{'options'})){
              foreach my $option (sort(keys(%{ $self->{'option'} }))){
                $text .= " option $option $self->{'option'}->{$option};";
              }
          }
      }

      if(defined( $self->{'suffix'} )){
          $text .= $self->{'suffix'};
      }else{
          $text .= '}';
          $text .= " # $self->{'comment'}" if(defined($self->{'comment'}));
      }
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

  sub subnets{
    my $self=shift;
    return $self->{'subnets'};
  }

  sub gethostbyip{
    my $self=shift;
    my $ip=shift;
    foreach my $subnet (@{ $self->subnets }){
        if(defined($subnet->hosts)){
            foreach my $host (@{ $subnet->hosts }){
                print $host->text."\n";
                print Data::Dumper->Dump([$host]);
            }
        }
    }
  }
1;

################################################################################
use File::Temp qw/ tempfile tempdir /;
my ($fh, $filename) = tempfile();
# system("/usr/bin/scp opt\@10.255.0.1:/var/db/dhcpd.leases $filename");
# my $leases = DHCPLeases->new($filename);
# # print $leases->table;
# print Data::Dumper->Dump([$leases->getleasesbymac("60:03:08:90:93:e8")]);
# print Data::Dumper->Dump([$leases->getleasesbymac("68:5b:35:a3:6f:51")]);
# print Data::Dumper->Dump([$leases->getleasesbyip("10.255.0.108")]);
# print Data::Dumper->Dump([$leases->getleasesbyip("10.255.0.120")]);

system("/usr/bin/scp opt\@10.255.0.1:/etc/dhcpd.conf $filename");
my $config = DHCPDConfig->new($filename);
print $config->gethostbyip('10.255.0.180');
