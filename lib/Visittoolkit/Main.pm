package Visittoolkit::Main;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use DateTime;
use DateTime::Format::Strptime;

sub top {
  my $self = shift;
  
  # Redirect to setup page
  return $self->redirect_to('/setup')
    unless $self->app->util->setup_completed;
  
  # Redirect to main wiki
  $self->render;
}

1;
