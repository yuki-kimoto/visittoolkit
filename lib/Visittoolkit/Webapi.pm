package Visittoolkit::Webapi;
use Mojo::Base 'Mojolicious::Controller';

sub report_update {
  my $self = shift;
  
  my $raw_params = $self->req->body_params->to_hash;
  
  my $validator = $self->app->validator;
  
  my $time_check = sub {
    my $value = shift;
    
    return unless defined $value;
    
    my $is_valid;
    if ($value =~ /^[0-9]+:[0-5][0-9]$/) {
      $value =~ s/^0+//;
      return [1, $value];
    }
    else { $is_valid = 0 }
    
    return $is_valid;
  };
  
  my $rule = [
    date => [
      'date_to_timepiece'
    ],
    book => {require => 0} => [
      'uint'
    ],
    brochure => {require => 0} => [
      'uint'
    ],
    time => {require => 0} => [
      $time_check
    ],
    magazine => {require => 0} => [
      'uint'
    ],
    return_visit => {require => 0} => [
      'uint'
    ],
    study => {require => 0} => [
      'uint'
    ]
  ];
  
  my $vresult = $validator->validate($raw_params, $rule);
  return $self->render(json => {ok => 0, error => 'invalid', validation_result => $vresult->to_hash})
    unless $vresult->is_ok;
  
  my $params = $vresult->data;
  my $date = delete $params->{date};
  return $self->render(json => {ok => 0, error => 'no_param'})
    unless keys %$params;
  
  my $dbi = $self->app->dbi;
  my $mreport = $dbi->model('serve_report_date');
  
  $mreport->update_or_insert($params, id => $date);
  
  return $self->render(json => {ok => 0, error => "db_error: $@"}) if $@;
  
  return $self->render(json => {ok => 1});
}

1;
