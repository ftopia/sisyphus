set :application, "sisyphus"

#default_run_options[:pty] = true
set :ssh_options, { :forward_agent => true }
set :use_sudo, false
set :normalize_asset_timestamps, false

require 'rvm/capistrano'
set :rvm_type, :system
set :rvm_ruby_string, '1.9.3'

require 'bundler/capistrano'
set :bundle_flags, "--without development,test --quiet --binstubs"

set :repository,  "git@github.com:ftopia/sisyphus.git"
set :scm, :git
set :branch, "master"
set :deploy_via, :remote_cache
set :user, "deploy"
set :deploy_to, "/home/deploy"

role :web, "ec2-54-216-129-160.eu-west-1.compute.amazonaws.com"
role :app, "ec2-54-216-129-160.eu-west-1.compute.amazonaws.com"

# if you want to clean up old releases on each deploy uncomment this:
# after "deploy:restart", "deploy:cleanup"

namespace :deploy do
  desc "Start the Thin processes"
  task :start, :roles => :app do
    run "cd #{current_path} && bin/thin start -C config/thin.yml"
  end

  desc "Stop the Thin processes"
  task :stop, :roles => :app do
    run "cd #{current_path} && bin/thin stop -C config/thin.yml"
  end

  desc "Restart the Thin processes"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && bin/thin restart -C config/thin.yml"
  end
end
