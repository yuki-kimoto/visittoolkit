package Visittoolkit::Main;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use DateTime;
use DateTime::Format::Strptime;

sub serve_report {
  my $self = shift;
  
  # 現在の年月
  my $month = $self->param('month');
  my $current_dt
    = DateTime::Format::Strptime->new(pattern => "%Y%m")->parse_datetime($month)
    || DateTime->now(time_zone => 'local', locale => 'ja');
  
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

sub admin_user {
  my $self = shift;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Users
  my $muser = $dbi->model('user');
  my $users = $muser->select->all;
  
  $self->render(users => $users);
}

sub edit_page {
  my $self = shift;
  
  my $wiki_id = $self->param('wiki_id');
  my $page_name = $self->param('page_name');
  
  # Exeption
  return $self->render_exeption unless defined $wiki_id && defined $page_name;
  
  # Wiki exists?
  my $wiki = $self->app->dbi->model('wiki')->select(
    where => {id => $wiki_id}
  )->one;
  
  # Not found
  return $self->render_not_found unless $wiki;
  
  # Page
  my $page = $self->app->dbi->model('page')->select(
    where => {wiki_id => $wiki_id, name => $page_name}
  )->one;
  $page = {not_exists => 1, wiki_id => $wiki_id, name => $page_name, content => ''}
    unless $page;
  
  # Render
  $self->render(page => $page);
}

sub top {
  my $self = shift;
  
  # Redirect to setup page
  return $self->redirect_to('/setup')
    unless $self->app->util->setup_completed;
  
  # Redirect to main wiki
  $self->render;
}

sub list_wiki {
  my $self = shift;
  
  # Pages
  my $wiki_id = $self->param('wiki_id');
  my $pages = $self->app->dbi->model('page')->select(
    where => {wiki_id => $wiki_id},
    append => 'order by name'
  )->all;
  
  # Not found
  return $self->render_not_found unless @$pages;
  
  # Render
  $self->render(pages => $pages);
}

sub page {
  my $self = shift;

  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    wiki_id => ['word'],
    page_name => ['not_blank']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  my $params = $vresult->data;

  # DBI
  my $dbi = $self->app->dbi;
  
  # Wiki id and page name
  my ($wiki_id, $page_name)
    = $self->_get_default_page($params->{wiki_id}, $params->{page_name});
  
  # Page
  my $page = $dbi->model('page')->select(
    where => {wiki_id => $wiki_id, name => $page_name},
  )->one;

  return $self->render_not_found unless defined $page;
  
  # HTML Filter
  my $hf = Visittoolkit::HTMLFilter->new;
  
  # Wiki link to a
  $page->{content} = $hf->parse_wiki_link($self, $page->{content}, $page->{wiki_id});
  
  # Content to html(Markdown)
  $page->{content} = markdown($hf->sanitize_tag($page->{content}));
  
  $self->render(page => $page);
}

sub page_history {
  my $self = shift;
  
  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    wiki_id => ['word'],
    page_name => ['not_blank']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  my $params = $vresult->data;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Wiki id and page name
  my ($wiki_id, $page_name)
    = $self->_get_default_page($params->{wiki_id}, $params->{page_name});

  # Page history
  my $page_histories = $dbi->model('page_history')->select(
    where => {wiki_id => $wiki_id, page_name => $page_name},
  )->all;
  
  # Not found
  return $self->render_not_found unless @$page_histories;
  
  # Render
  $self->render(
    page_histories => $page_histories,
    wiki_id => $wiki_id,
    page_name => $page_name
  );
}

sub _get_default_page {
  my ($self, $wiki_id, $page_name) = @_;
  
  #DBI
  my $dbi = $self->app->dbi;
  
  # Wiki id
  unless (defined $wiki_id) {
    $wiki_id = $dbi->model('wiki')->select('id', append => 'order by main desc')->value;
  }
  
  # Page name
  unless (defined $page_name) {
    $page_name = $dbi->model('page')->select(
      'name',
      where => {wiki_id => $wiki_id},
      append => 'order by main desc'
    )->value;
  }
  
  return ($wiki_id, $page_name);
}

1;
