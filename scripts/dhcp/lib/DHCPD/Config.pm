use DHCPD::Config::Subnet;
package DHCPD::Config;
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
            push(@{ $self->{'subnets'} }, DHCPD::Config::Subnet->new(join("\n",@working)));
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

  sub text{
    my $self=shift;
    my $text = '';
    foreach my $item (@{ $self->{'global-options'} }){
      $text .= $item."\n";
    }
    foreach my $subnet (@{ $self->{'subnets'} }){
      $text .= $subnet->textconfig;
    }
    return $text."\n";
  }

1;
