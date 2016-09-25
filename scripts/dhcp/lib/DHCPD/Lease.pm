package DHCPD::Lease;
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
