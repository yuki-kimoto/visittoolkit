package Visittoolkit::API;
use Mojo::Base -base;

has 'controller';

sub sum_time {
  my ($self, $times) = @_;
  
  my $hour_total = 0;
  my $min_total = 0;
  
  for my $time (@$times) {
    my ($hour, $min) = $time =~ /^(\d+):(\d+)$/;
    $hour_total += $hour;
    $min_total += $min;
  }
  
  my $rest_hour = int($min_total / 60);
  my $rest_min = $min_total % 60;
  
  $hour_total += $rest_hour;
  
  my $total_time = sprintf('%d:%02d', $hour_total, $rest_min);
  
  return $total_time;
}

1;
