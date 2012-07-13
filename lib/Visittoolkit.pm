package Visittoolkit;

our $VERSION = '0.01';

use Mojo::Base 'Mojolicious';
use DBIx::Custom;
use Validator::Custom;
use Visittoolkit::Util;
use Carp 'croak';
use Visittoolkit::API;
use Time::Piece;

has util => sub { Visittoolkit::Util->new(app => shift) };
has validator => sub { Validator::Custom->new };
has 'dbi';
has 'dbpath';

sub startup {
  my $self = shift;
  
  # Load Pure Perl DateTime
  my $lib = $self->home->rel_file('extlib/lib/perl5/datetimelib');
  eval "use lib '$lib'";
  croak $@ if $@;
  $ENV{PERL_DATETIME_PP} = 1; # for DateTime
  $ENV{PV_TEST_PERL} = 1;     # for Params::Validate
  require DateTime;
  
  # API
  $self->helper(vtk => sub {
    my $self = shift;
    
    return Visittoolkit::API->new(controller => $self);
  });
  
  # Config
  my $config = $self->plugin('Config');
  
  # Secret
  $self->secret($config->{secret});
  
  # Database
  my $db = "ringowiki";
  my $dbpath = $ENV{VISITTOOLKIT_DBPATH} // $self->home->rel_file("db/$db");
  $self->dbpath($dbpath);
  
  # DBI
  my $dbi = DBIx::Custom->connect(
    dsn => "dbi:SQLite:$dbpath",
    option => {sqlite_unicode => 1},
    connector => 1
  );
  $self->dbi($dbi);
  
  # Models
  my $models = [
    # Wiki
    {
      table => 'wiki',
      primary_key => 'id'
    },
    
    # Page
    {
      table => 'page',
      primary_key => ['wiki_id', 'name'],
      ctime => 'ctime',
      mtime => 'mtime'
    },
    
    # Page History
    {
      table => 'page_history',
      primary_key => ['wiki_id', 'page_name', 'version'],
      ctime => 'ctime'
    },
    
    # User
    {
      table => 'user'
    },
    # Report
    {
      table => 'serve_report_date',
      primary_key => 'date'
    }
  ];
  $dbi->create_model($_) for @$models;
  $dbi->setup_model;
  
  $dbi->register_filter(
    tp_to_date => sub {
        my $tp = shift;
        
        return '' unless defined $tp;
        return $tp unless ref $tp;
        return $tp->strftime('%Y-%m-%d');
    },
    date_to_tp => sub {
        my $date = shift;
        
        return unless $date;
        return localtime Time::Piece->strptime($date, '%Y-%m-%d');
    }
  );
  
  $dbi->type_rule(
    into1 => {
      date => 'tp_to_date'
    },
    from1 => {
      date => 'date_to_tp'
    }
  );
  
  # Validator;
  my $vc = $self->validator;
  $vc->register_constraint(
    word => sub {
      my $value = shift;
      return 0 unless defined $value;
      return $value =~ /^[a-zA-Z_]+$/ ? 1 : 0;
    }
  );
  
  # Route
  my $r = $self->routes;

  # SQLite viewer (only development)
  if ($self->mode eq 'development') {
  
    my $viewer_dbi = DBIx::Custom->connect(
      dsn => "dbi:SQLite:$dbpath",
      option => {sqlite_unicode => 1},
      connector => 1
    );

    $self->plugin('SQLiteViewerLite', dbi => $viewer_dbi);
  }
  
  # Brige
  {
    my $r = $r->under(sub {
      my $self = shift;
      
      # Database is setupped?
      unless ($self->app->util->setup_completed) {
        my $path = $self->req->url->path->to_string;
        return 1 if $path =~ m|^(/api)?/setup|;
        $self->redirect_to('/setup');
        return 0; 
      }
      
      return 1;
    });

    # Route automatically
    $self->plugin('AutoRoute', {ignore => ['layouts']});
  
    # Web API
    {
      my $r = $r->route('/api')->to('webapi#');
      $r->post('/report/update')->to('#report_update');

      if ($self->mode eq 'development') {
        # Initialize wiki
        $r->post('/init')->to('#init');
        
        # Re-setupt wiki
        $r->post('/resetup')->to('#resetup');
        
        # Create wiki
        $r->post('/create-wiki')->to('#create_wiki');
        
        # Remove all pages
        $r->post('/init-pages')->to('#init_pages');
      }
    }
  }
}

1;
