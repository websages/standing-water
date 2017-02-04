use DHCPD::Config::Subnet::Host;
package DHCPD::Config::Subnet;
use Net::CIDR;
use NetAddr::IP;

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
    my @suffix = ();
    my @working = ();
    my $character='';
    while($character ne '{'){
      $character=shift(@blobby);
      push(@prefix,$character) unless $character eq '{';
    }
    $self->{'prefix'} = join('',@prefix);
    $self->{'prefix'}=~s/^\s+//;
    $self->{'prefix'}=~s/\s+$//;
    if($self->{'prefix'}=~m/subnet\s+(\S+)\s+netmask\s+(\S+)/){
      $self->{'subnet'}=$1;
      $self->{'netmask'}=$2;
      delete $self->{'prefix'};
    }
    $character='';
    while($character ne '}'){
      $character=pop(@blobby);
      unshift(@suffix,$character) unless $character eq '}';
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
            push(@{ $self->{'hosts'} }, DHCPD::Config::Subnet::Host->new(join("\n",@working)));
            @working= ();
          }else{
            push(@{ $self->{'config_items'} },join('',@working));
            @working= ();
          }
        }
      }
    }
    map( { $_=~s/^\s+//; $_=~s/\s+$//; $_=~s/;$//; }  @{$self->{'config_items'}});
    foreach my $item (@{ $self->{'config_items'} }){
      if($item =~m/#.*/){
        $item=~s/#*\s*//;
        push(@{ $self->{'comments'} }, $item);
        next;
      }
      @config_line = split(/\s+/,$item);
      my $key = shift (@config_line);
      if($key eq "option"){
        $key = shift (@config_line);
        $self->{'config'}->{'option'}->{$key} = join(' ',@config_line);
      }else{
        print STDERR "Duplicate key [ $key ] on subnet" if defined($self->{'config'}->{$key});
        $self->{'config'}->{$key} = join(' ',@config_line);
      }
    }
    delete $self->{'config_items'};
    return $self;
  }

  sub range{
    my $self=shift;
    return $self->{'config'}->{'range'};
  }

  sub routers{
    my $self=shift;
    return $self->{'config'}->{'option'}->{'routers'};
  }

  sub hosts{
    my $self=shift;
    return $self->{'hosts'};
  }

  sub subnet{
    my $self=shift;
    return $self->{'subnet'};
  }

  sub netmask{
    my $self=shift;
    return $self->{'netmask'};
  }

  sub textconfig{
    my $self = shift;
    my $textconfig = '';
    $textconfig .= "subnet ".$self->subnet." netmask ".$self->netmask." {";
    $textconfig .= "\n" if(defined($self->{'config'})||defined($self->{'hosts'})||defined($self->{'comments'}));
    foreach my $key (keys(%{ $self->{'config'} })){
      if($key eq 'option'){
        foreach my $option (keys(%{ $self->{'config'}->{$key} })){
          $textconfig .= "    option $option $self->{'config'}->{$key}->{$option};\n";
        }
      }else{
        $textconfig .= "    $key $self->{'config'}->{$key};\n";
      }
    }
    foreach my $comment (@{ $self->{'comments'} }){
        $textconfig .= "    # $comment\n";
    }
    if(defined ($self->{'hosts'})){
      foreach my $host (@{ $self->{'hosts'} }){
        $textconfig .= $host->entry_oneline."\n";
        # print $host->entry_config_block."\n";
      }
    }
    $textconfig .= "}\n\n";
  }

  sub ip_addresses{
    my $self = shift;
    my $n = NetAddr::IP->new( Net::CIDR::cidr2range(Net::CIDR::addrandmask2cidr($self->subnet, $self->netmask)));
    my @addresses;
    for my $ip( @{$n->hostenumref} ) {
        push(@addresses,$ip->addr);
    }
    return @addresses;
  }

  sub dynamic_ip_addresses{
    my $self = shift;
    my ($start_dyn, $end_dyn) = split(/\s+/,$self->range);
    $start = unpack N => pack CCCC => split /\./ => $start_dyn;
    $end = unpack N => pack CCCC => split /\./ => $end_dyn;
    my @addresses;
    for(my $i=$start;$i <= $end; $i++){
        push(@addresses, join '.', unpack 'C4', pack 'N', $i);
    }
    return @addresses;
  }

  sub static_ip_addresses{
    my $self = shift;
    my @addresses;
    if(defined($self->hosts)){
      foreach my $host (@{$self->hosts}){
        push(@addresses, $host->ip);
      }
    }
    return @addresses;
  }

  sub available_ip_addresses{
    my $self = shift;
    @all_addresses = $self->ip_addresses;

    @used_addresses = $self->dynamic_ip_addresses;
    foreach my $static ($self->static_ip_addresses){ push(@used_addresses,$static); }
    push(@used_addresses,$self->routers);

    my %used = map {$_ => '1'} @used_addresses;
    my @diff;
    while (my $addr = shift(@all_addresses)){
      push(@diff,$addr) unless(exists $used{$addr});
    }
    return @diff;
  }

  sub next_available_ip{
    my $self = shift;
    my @available = $self->available_ip_addresses;
    return shift(@available);
  }

  sub add_host{
    my $self = shift;
    my $hostname = shift;
    return undef unless(defined($hostname));
    my $macaddr = shift;
    return undef unless(defined($macaddr));
    my $ipaddress = shift||$self->next_available_ip;
    push(@{ $self->{'hosts'} }, DHCPD::Config::Subnet::Host->new("host $hostname { hardware ethernet $macaddr; fixed-address $ipaddress; option host-name \"$hostname\"; } # $hostname"));
  }

  sub del_host{
    my $self = shift;
    my $hostname = shift;
    return undef unless(defined($hostname));
    my $new = [];
    my $removed = false;
    while( my $host=shift(@{ $self->{'hosts'}  })){ 
      if($host->name eq $hostname){
          $removed = true;
      }else{
        push(@{ $new },$host)
      }
      $self->{'hosts'}=$new;
    }
    return $removed;
  }
1;
