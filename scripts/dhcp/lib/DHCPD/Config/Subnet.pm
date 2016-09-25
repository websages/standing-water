use DHCPD::Config::Subnet::Host;
package DHCPD::Config::Subnet;

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

1;
