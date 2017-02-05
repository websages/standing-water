package DHCPD::Worker;
  use Data::Dumper;
  use JSON;
  use Net::MQTT::Simple::SSL;
  use File::Temp qw/ tempfile tempdir /;
  sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->{'remote_user'} = shift||'opt';
    $self->{'remote_host'} = shift||'10.255.0.1';
    $self->{'json'} = JSON->new->allow_nonref;
    $self->{'config'} = $self->refresh;
    return $self;
  }

  sub config{
    my $self = shift;
    return $self->{'config'};
  }

  sub refresh {
      my $self = shift;
      # Scrape our leases
      my ($fh, $filename) = tempfile();
      system("/usr/bin/scp $self->{'remote_user'}\@$self->{'remote_host'}:/var/db/dhcpd.leases $filename > /dev/null 2>&1");
      my $leases = DHCPD::Leases->new($filename);

      # Get our dhcpd.config
      system("/usr/bin/scp $self->{'remote_user'}\@$self->{'remote_host'}:/etc/dhcpd.conf $filename > /dev/null 2>&1");
      $self->{'config'} = DHCPD::Config->new($filename);
      return $self->{'config'};

  }

  sub commit{
      my $self = shift;
      $pid = open(DHCPDCONF, "| /usr/bin/ssh $self->{'remote_user'}\@$self->{'remote_host'} 'cat - | sudo tee /etc/dhcpd.conf'>/dev/null") or die "Couldn't fork: $!\n";
      print DHCPDCONF $self->{'config'}->text;
      close(DHCPDCONF) or warn "Couldn't close: $!\n";
      open (CHECKBOUNCE, "/usr/bin/ssh $self->{'remote_user'}\@$self->{'remote_host'} '/usr/bin/sudo /etc/rc.d/dhcpd restart'|");
      my $output=<CHECKBOUNCE>;
      close(CHECKBOUNCE);
      print $output;
  }

1;
