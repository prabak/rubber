# This is a sample Capistrano config file for rubber

set :rails_env, Rubber.env

on :load do
  set :application, rubber_env.app_name
  set :runner,      rubber_env.app_user
  set :deploy_to,   "#{rubber_env.mount_directory}/#{application}-#{Rubber.env}"
  set :copy_exclude, [".bundle/*", "log/*", ".rvmrc", ".rbenv-version"] # removed ".git/*" from this list due to asset compilation code.
  set :assets_role, [:app]
end

# Use a simple directory tree copy here to make demo easier.
# You probably want to use your own repository for a real app
ssh_options[:forward_agent] = true # tell Capistrano to use agent forwarding with this command. Agent forwarding can make key management much simpler as it uses your local keys instead of keys installed on the server.
set :scm, :git
set :branch, rubber_env.deployment_branch
set :deploy_via, :remote_cache # in most cases we want this options, else each deploy will do a full repository clone every time
set :repository, rubber_env.code_repository
set :last_revision, nil # use this variable to store the revision from git before figuring out if we need to compile the assets

# Easier to do system level config as root - probably should do it through
# sudo in the future.  We use ssh keys for access, so no passwd needed
set :user, 'root'
set :password, nil

# having issue with connection failed for: staging.getcarta.com (Timeout::Error: execution expired)
set :ssh_timeout, 60

# Use sudo with user rails for cap deploy:[stop|start|restart]
# This way exposed services (mongrel) aren't running as a privileged user
set :use_sudo, true

# How many old releases should be kept around when running "cleanup" task
set :keep_releases, 3

# Lets us work with instances without having to checkin config files
# Lets us work with staging instances without having to checkin config files
# (instance*.yml + rubber*.yml) for a deploy.  This gives us the
# convenience of not having to checkin files for instances, as well as 
# the safety of forcing it to be checked in for production and staging.
set :push_instance_config, (Rubber.env != 'production' || Rubber.env != 'staging')

# don't waste time bundling gems that don't need to be there 
set :bundle_without, [:development, :test] if (Rubber.env == 'production' || Rubber.env == 'staging')

# Allow us to do N hosts at a time for all tasks - useful when trying
# to figure out which host in a large set is down:
# RUBBER_ENV=production MAX_HOSTS=1 cap invoke COMMAND=hostname
max_hosts = ENV['MAX_HOSTS'].to_i
default_run_options[:max_hosts] = max_hosts if max_hosts > 0

# Allows the tasks defined to fail gracefully if there are no hosts for them.
# Comment out or use "required_task" for default cap behavior of a hard failure
rubber.allow_optional_tasks(self)

# Wrap tasks in the deploy namespace that have roles so that we can use FILTER
# with something like a deploy:cold which tries to run deploy:migrate but can't
# because we filtered out the :db role
namespace :deploy do
  rubber.allow_optional_tasks(self)
  tasks.values.each do |t|
    if t.options[:roles]
      task t.name, t.options, &t.body
    end
  end
end

namespace :deploy do
  namespace :assets do
    rubber.allow_optional_tasks(self)
    tasks.values.each do |t|
      if t.options[:roles]
        task t.name, t.options, &t.body
      end
    end
  end
end

# load in the deploy scripts installed by vulcanize for each rubber module
Dir["#{File.dirname(__FILE__)}/rubber/deploy-*.rb"].each do |deploy_file|
  load deploy_file
end

# capistrano's deploy:cleanup doesn't play well with FILTER
after "deploy", "cleanup"
after "deploy:migrations", "cleanup"
task :cleanup, :except => { :no_release => true } do
  count = fetch(:keep_releases, 5).to_i
  
  rsudo <<-CMD
    all=$(ls -x1 #{releases_path} | sort -n);
    keep=$(ls -x1 #{releases_path} | sort -n | tail -n #{count});
    remove=$(comm -23 <(echo -e "$all") <(echo -e "$keep"));
    for r in $remove; do rm -rf #{releases_path}/$r; done;
  CMD
end

# We need to ensure that rubber:config runs before asset precompilation in Rails, as Rails tries to boot the environment,
# which means needing to have DB access.  However, if rubber:config hasn't run yet, then the DB config will not have
# been generated yet.  Rails will fail to boot, asset precompilation will fail to complete, and the deploy will abort.
if Rubber::Util.has_asset_pipeline?
  load 'deploy/assets'

  callbacks[:after].delete_if {|c| c.source == "deploy:assets:precompile"}
  callbacks[:before].delete_if {|c| c.source == "deploy:assets:symlink"}
  before "deploy:assets:precompile", "deploy:assets:symlink"
  after "rubber:config", "deploy:assets:precompile"
end

# before deploy update is called, set the latest git revision. NOTE: for some reason, in deploy:assets:precompile task, the latest revision is not set properly
before "deploy:update", "deploy:update_last_revision"

# The following is to speed up the asset compilation process during deployment.
# See: http://stackoverflow.com/questions/12919509/capistrano-deploy-assets-precompile-never-compiles-assets-why
# Only compile the assets, if it needs to be. i.e. ["vendor/assets/", "app/assets/", "lib/assets", "Gemfile", "Gemfile.lock"]
# Override the capistrano default task
namespace :deploy do
  namespace :assets do
    task :precompile, :roles => :web, :except => { :no_release => true } do
      logger.info "Figuring out if assets needs to be compiled or not ..."
      force_compile       = false
      changed_asset_count = 0
      # last_revision might be nil hence, catch exception.
      begin
        asset_changing_files = ["vendor/assets/", "app/assets/", "lib/assets", "Gemfile", "Gemfile.lock"]
        asset_changing_files = asset_changing_files.select do |f| # we do not have lib/assets right now. select the directories that exists
          File.exists? f
        end
        changed_asset_count = capture("cd #{latest_release} && #{source.local.log(last_revision)} #{asset_changing_files.join(" ")} | wc -l").to_i
      rescue => e
        logger.info "An exception as occured while fetching the current revision. This is to be expected if this is your first deploy to this machine."
        force_compile = true
      end
      if changed_asset_count > 0 || force_compile
        logger.info "#{changed_asset_count} assets have changed. Pre-compiling"
        run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assets:precompile}
      else
        logger.info "Skipping asset pre-compilation because there were no asset changes"
      end
    end
  end
end

namespace :deploy do
  task :update_last_revision, :roles => :web, :except => { :no_release => true } do
    begin
      set :last_revision, current_revision
      logger.info "Updating the last revision: #{last_revision}"
    rescue => e
      logger.info "Problem updating the last revision"
    end
  end
end