package Visittoolkit;

our $VERSION = '0.01';

use Mojo::Base 'Mojolicious';
use DBIx::Custom;
use Validator::Custom;
use Visittoolkit::Util;

has util => sub { Visittoolkit::Util->new(app => shift) };
has validator => sub { Validator::Custom->new };
has 'dbi';
has 'dbpath';

sub startup {
  my $self = shift;
  
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
    }
  ];
  $dbi->create_model($_) for @$models;
  
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

    # SQLite viewer (only development)
    $self->plugin('SQLiteViewerLite', dbi => $dbi)
      if $self->mode eq 'development';
    
    # Main
    {
      my $r = $r->route->to('main#');

      # Top
      $r->get('/')->to('#top')->name('top');
      
      # Login
      $r->get('/login')->to('#login');
      
      # Admin
      $r->get('/admin')->to('#admin');
      
      # Admin user
      $r->get('/admin/user')->to('#admin_user');

      # Setup
      $r->get('/setup')->to('#setup');
      
      # Create wiki
      $r->get('/create-wiki')->to('#create_wiki');
      
      # List wiki
      $r->get('/list-wiki/:wiki_id')->to('#list_wiki')->name('list-wiki');

      # Create page
      $r->get('/create-page')->to('#create_page');
    
      # Edit page
      $r->get('/edit-page/:wiki_id/:page_name')->to('#edit_page')->name('edit-page');

      # Page
      $r->get('/wiki/:wiki_id/:page_name')->to('#page', page_name => '')->name('page');
      
      # Page history
      $r->get('/page-history/:wiki_id/:page_name')
        ->to('#page_history', page_name => '')->name('page_history');
    }

    # API
    {
      my $r = $r->route('/api')->to('api#');

      # Setup wiki
      $r->post('/setup')->to('#setup');

      # Edit page
      $r->post('/edit-page')->to('#edit_page');

      # Preview
      $r->post('/preview')->to('#preview');
      
      # Diff
      $r->post('/content-diff')->to('#content_diff');

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
