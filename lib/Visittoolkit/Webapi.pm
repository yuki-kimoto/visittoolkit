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

our $TABLE_INFOS = {
  setup => [],
  user => [
    'id not null unique',
    'password not null',
    'admin not null',
  ],
  serve_report_date => [
    "date date unique not null default ''",
    'book integer not null default 0',
    'brochure integer not null default 0',
    'time not null default 0',
    'magazine integer not null default 0',
    'return_visit integer not null default 0',
    'study integer not null default 0'
  ],
  serve_report_month => [
    "year not null default ''",
    "month not null default ''",
    'study integer not null default 0',
    'unique(year, month)'
  ]
};

sub init {
  my $self = shift;
  
  my $dbi = $self->app->dbi;
  
  my $table_infos = $dbi->select(
    column => 'name',
    table => 'main.sqlite_master',
    where => "type = 'table' and name <> 'sqlite_sequence'"
  )->all;
  
  eval {
    $dbi->connector->txn(sub {
      for my $table_info (@$table_infos) {
        my $table = $table_info->{name};
        $self->app->dbi->execute("drop table $table");
      }
    });
  };
  
  my $success = !$@ ? 1 : 0;
  return $self->render_json({success => $success});
}

sub resetup {
  my $self = shift;
  
  # Prefix
  my $prefix_new = '__visittoolkit_new__';
  my $prefix_old = '__visittoolkit_old__';
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Drop new tables
  my $new_tables = $dbi->select(
    column => 'name',
    table => 'main.sqlite_master',
    where => "type = 'table' and name like '$prefix_new%'"
  )->values;
  $dbi->execute("drop table $_") for @$new_tables;

  # Drop old tables
  my $old_tables = $dbi->select(
    column => 'name',
    table => 'main.sqlite_master',
    where => "type = 'table' and name like '$prefix_old%'"
  )->values;
  $dbi->execute("drop tabe $_") for @$old_tables;
  
  # Create new tables
  eval {
    $self->_create_table("$prefix_new$_" => $TABLE_INFOS->{$_}) for keys %$TABLE_INFOS;
  };
  if ($@) {
    $self->app->log->error($@);
    return $self->render(json => {success => 0});
  }
  
  # Get current tables
  my %current_tables = $dbi->select(
    column => 'name, 1',
    table => 'main.sqlite_master',
    where => "type = 'table' and name <> 'sqlite_sequence' and not name like '$prefix_new%'"
  )->flat;

  # Copy current table to new table
  for my $table (keys %$TABLE_INFOS) {
    next unless $current_tables{$table};
    
    my $new_column_info_result = $dbi->execute("PRAGMA TABLE_INFO('$prefix_new$table')");
    my $new_columns = {};
    while (my $row = $new_column_info_result->fetch_hash) {
      $new_columns->{$row->{name}} = 1; 
    }
    
    my $current_column_info_result = $dbi->execute("PRAGMA TABLE_INFO('$table')");
    my @current_columns;
    while (my $row = $current_column_info_result->fetch_hash) {
      push @current_columns, $row->{name};
    }
    
    my @columns = grep { $new_columns->{$_} } @current_columns;
    my $columns = join ', ', @current_columns;
    
    my $result = $dbi->select($columns, table => $table);
    my $new_table = "$prefix_new$table";
    while (my $row = $result->fetch_hash) {
      $dbi->insert($row, table => $new_table);
    }
  }
  
  # Rename table
  $dbi->connector->txn(sub {
    # Rename current table to old
    $dbi->execute("alter table $_ rename to $prefix_old$_")
      for keys %current_tables;
    
    # Rename new table to current
    $dbi->execute("alter table $prefix_new$_  rename to $_")
      for keys %$TABLE_INFOS;
  });
  
  # Drop old table
  $dbi->execute("drop table $prefix_old$_")
    for keys %current_tables;
  
  # Cleanup
  $dbi->execute('vacuum');
  
  $self->render_json({success => 1});
}

sub setup {
  my $self = shift;
  
  # Validation
  my $params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    admin_user
      => {message => '管理者IDが入力されていません。'}
      => ['not_blank'],
    admin_password1
      => {message => '管理者パスワードが入力されていません。'}
      => ['ascii'],
    {admin_password => [qw/admin_password1 admin_password2/]}
       => {message => 'パスワードが一致しません。'}
       => ['duplication']
  ];
  my $vresult = $self->app->validator->validate($params, $rule);
  return $self->render_json({success => 0, validation => $vresult->to_hash})
    unless $vresult->is_ok;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Create tables
  $dbi->connector->txn(sub {
    $self->_create_table($_, $TABLE_INFOS->{$_}) for keys %$TABLE_INFOS;
  });
  
  $self->render(json => {success => 1});
}

sub _create_table {
  my ($self, $table, $columns) = @_;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Check table existance
  my $table_exist = 
    eval { $dbi->select(table => $table, where => '1 <> 1'); 1};
  
  # Create table
  $columns = ['rowid integer primary key autoincrement', @$columns];
  unless ($table_exist) {
    my $sql = "create table $table (";
    $sql .= join ', ', @$columns;
    $sql .= ')';
    $dbi->execute($sql);
  }
}

1;
