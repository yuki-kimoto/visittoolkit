package Visittoolkit::Webapi;
use Mojo::Base 'Mojolicious::Controller';

sub report_update {
  my $self = shift;
  
  my $raw_params = $self->req->body_params->to_hash;
  warn $self->dumper($raw_params);
  
  my $validator = $self->app->validator;
  
  my $rule = [
    book => {require => 0} => [
      'uint'
    ],
    brochure => {require => 0} => [
      'uint'
    ],
    time => {require => 0} => [
      'any'
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
  return $self->render(json => {ok => 0, error => 'no_param'})
    unless keys %$params;
  
  my $dbi = $self->app->dbi;
  my $mreport = $dbi->model('serve_report_date');
  
  eval { $mreport->insert($params) };
  
  return $self->render(json => {ok => 0, error => "db_error: $@"}) if $@;
  
  return $self->render(json => {ok => 1});
}

1;
