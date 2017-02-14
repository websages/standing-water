package DHCPD::Worker;
  use Data::Dumper;
  use JSON;
  use Net::MQTT::Simple::SSL;
  use File::Temp qw/ tempfile tempdir /;
  sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->{'options'} = shift||{};
    $self->{'dhcpd_user'} = $self->{'options'}->{'dhcpd_user'}||'opt';
    $self->{'dhcpd_host'} = $self->{'options'}->{'dhcpd_host'}||'10.255.0.1';
    $self->{'tftpd_user'} = $self->{'options'}->{'tftpd_user'}||'opt';
    $self->{'tftpd_host'} = $self->{'options'}->{'tftpd_host'}||'10.255.12.51';
    $self->{'pxe_root'} = $self->{'options'}->{'pxe_root'}||'/opt/tftpboot/'
    $self->{'pxelinux_cfg'} = $self->{'options'}->{'pxe_root'}."/pxelinux.cfg";
    $self->{'pxelinux_menus'} = $self->{'options'}->{'pxe_root'}."/pxelinux.menus";
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
      system("/usr/bin/scp $self->{'dhcpd_user'}\@$self->{'dhcpd_host'}:/var/db/dhcpd.leases $filename > /dev/null 2>&1");
      my $leases = DHCPD::Leases->new($filename);

      # Get our dhcpd.config
      system("/usr/bin/scp $self->{'dhcpd_user'}\@$self->{'dhcpd_host'}:/etc/dhcpd.conf $filename > /dev/null 2>&1");
      $self->{'config'} = DHCPD::Config->new($filename);
      return $self->{'config'};

  }

  sub commit{
      my $self = shift;
      $pid = open(DHCPDCONF, "| /usr/bin/ssh $self->{'dhcpd_user'}\@$self->{'dhcpd_host'} 'cat - | sudo tee /etc/dhcpd.conf'>/dev/null") or die "Couldn't fork: $!\n";
      print DHCPDCONF $self->{'config'}->text;
      close(DHCPDCONF) or warn "Couldn't close: $!\n";
      open (CHECKBOUNCE, "/usr/bin/ssh $self->{'dhcpd_user'}\@$self->{'dhcpd_host'} '/usr/bin/sudo /etc/rc.d/dhcpd restart'|");
      my $output=<CHECKBOUNCE>;
      close(CHECKBOUNCE);
      print $output;
  }

1;
