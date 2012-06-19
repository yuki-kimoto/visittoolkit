package Visittoolkit::Servereport;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use DateTime;
use DateTime::Format::Strptime;

sub main {
  my $self = shift;

  # 現在の年月
  my $date = $self->param('date');
  my %opts = (time_zone => 'local', locale => 'ja');
  my $current_dt
    = DateTime::Format::Strptime->new(pattern => "%Y%m%d", %opts)->parse_datetime($date)
    || DateTime->now(%opts);
  $current_dt->locale('ja');
  
  # 前の日
  my $prev_dt = $current_dt->clone->add(days => -1);
  
  # 次の日
  my $next_dt = $current_dt->clone->add(days => 1);
  
  $self->render(
    prev_dt => $prev_dt,
    current_dt => $current_dt,
    next_dt => $next_dt
  );
}

# 月表示
sub month {
  my $self = shift;
  
  # 現在の年月
  my $month = $self->param('month');
  my %opts = (time_zone => 'local', locale => 'ja');
  my $current_dt
    = DateTime::Format::Strptime->new(pattern => "%Y%m", %opts)->parse_datetime($month)
    || DateTime->now(%opts);
  
  # 前の月
  my $prev_dt = $current_dt->clone->add(months => -1, end_of_month => 'limit');
  
  # 次の月
  my $next_dt = $current_dt->clone->add(months => 1, end_of_month => 'limit');
=pod
  
  my $last_mday = $dt->month;
  
  die $self->dumper([
    $dt->year,
    $dt->month,
    DateTime->last_day_of_month(year => $dt->year, month => $dt->month)->day]);
=cut
  
  $self->render(
    prev_dt => $prev_dt,
    current_dt => $current_dt,
    next_dt => $next_dt
  );
}

1;
