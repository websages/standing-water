package DHCPD::Config::Subnet::Host;
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
      push(@prefix,$character) unless $character eq '{';
    }
    $self->{'prefix'} = join('',@prefix);
    $self->{'prefix'} =~ s/^\s+//;
    $self->{'prefix'} =~ s/\s+$//;
    if($self->{'prefix'} =~ m/host\s+(\S+)/){
      $self->{'host'} = $1;
      delete $self->{'prefix'};
    }

    $character='';
    while($character ne '}'){
      $character=pop(@blobby);
      unshift(@suffix,$character) unless $character eq '}';
    }
    $self->{'suffix'} = join('',@suffix);
    $self->{'suffix'} =~ s/^\s+//;
    $self->{'suffix'} =~ s/\s+$//;
    if($self->{'suffix'} =~ m/#\s*(.*)/){
       $self->{'comment'} = $1;
       $self->{'suffix'};
       delete $self->{'suffix'};
    }

    $self->{'block'} = join('', @blobby);
    $self->{'block'} =~ s/^\s+//;
    $self->{'block'} =~ s/\s+$//;
    $self->{'block'} =~ s/\n/ /;
    @{$self->{'items'}} = split(/;/,$self->{'block'});
    delete $self->{'block'};
    map( { $_=~s/^\s+//; $_=~s/\s+$//; }  @{$self->{'items'}});

    while(my $item=shift(@{$self->{'items'}})){
      @config_line = split(/\s+/,$item);
      my $key = shift (@config_line);
      if($key eq "option"){
        $key = shift (@config_line);
        $self->{'config'}->{'option'}->{$key} = join( ' ',@config_line );
      }else{
        print STDERR "Duplicate key [ $key ] on subnet" if defined($self->{'config'}->{$key});
        $self->{'config'}->{$key} = join(' ',@config_line);
      }
    }
    delete $self->{'items'};
    return $self;
  }

  sub host{
    my $self = shift;
    return $self->{'host'};
  }

  sub name{
    my $self = shift;
    return $self->{'host'};
  }

  sub config{
    my $self = shift;
    return $self->{'config'};
  }

  sub macaddr{
    my $self = shift;
    return $self->hardware;
  }

  sub ethernet{
    my $self = shift;
    return $self->hardware;
  }

  sub hardware{
    my $self = shift;
    return $self->{'config'}->{'hardware'};
  }

  sub ip{
    my $self = shift;
    return $self->fixed_address;
  }

  sub ipaddress{
    my $self = shift;
    return $self->fixed_address;
  }

  sub fixed_address{
    my $self = shift;
    return $self->{'config'}->{'fixed-address'};
  }

  sub option{
    my $self = shift;
    return $self->{'config'}->{'option'};
  }

  sub options{
    my $self = shift;
    return $self->{'config'}->{'option'};
  }

  sub comment{
    my $self = shift;
    return $self->{'comment'};
  }

  sub pad_print{
    my $self = shift;
    my $length = shift;
    my $content = shift;
    my $block = $content;
    my $padding = $length - length($content);
    for(my $space=0; $space < $padding; $space++){
      $block.=' ';
    }
    return $block;
  }

  sub entry_oneline{
    my $self = shift;
    my $padding = shift;
    my $line = '';
    $line .= $self->pad_print(4);
    $line .= $self->pad_print(20,"host ".$self->host." ");
    $line .= $self->pad_print(2,'{');
    $line .= $self->pad_print(37, "hardware ".$self->hardware."; ");
    $line .= $self->pad_print(29, "fixed-address ".$self->fixed_address."; ");
    foreach my $key (keys($self->options)){
      $line .= $self->pad_print(35,"option $key ".$self->option->{$key}."; ");
    }
    $line .= $self->pad_print(2,'}');
    $line .= $self->pad_print(20, "# ".$self->comment) if($self->comment);
    return $line;
  }

  sub entry_config_block{
    my $self = shift;
    my $indent = shift||2;
    my $block = '';
    $block .= $self->pad_print($indent);
    $block .= $self->pad_print(0,"host ".$self->host." ");
    $block .= $self->pad_print($indent,"{\n");

    if($self->comment){
      $block .= $self->pad_print($indent * 2);
      $block .= "# ".$self->comment."\n";
    }

    $block .= $self->pad_print($indent * 2);
    $block .= "hardware ".$self->hardware.";\n";

    $block .= $self->pad_print($indent * 2);
    $block .= "fixed-address ".$self->fixed_address.";\n";

    foreach my $key (keys($self->options)){
      $block .= $self->pad_print($indent * 2);
      $block .= "option $key ".$self->option->{$key}.";\n";
    }

    $block .= $self->pad_print($indent);
    $block .= "}\n";
    return $block;
  }

1;
