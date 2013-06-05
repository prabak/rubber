namespace :rubber do

  namespace :node do

    rubber.allow_optional_tasks(self)

    after "rubber:install_packages", "rubber:node:install"

    task :install, :roles => :node do
      rubber.sudo_script 'install_node', <<-ENDSCRIPT
        # See the following: http://shapeshed.com/compiling-nodejs-from-source-on-ubuntu-10-04/
        if ! node --version | grep "#{rubber_env.node_server_version}" &> /dev/null; then
          # Fetch the sources.
          wget http://nodejs.org/dist/#{rubber_env.node_server_version}/node-#{rubber_env.node_server_version}.tar.gz
          tar -zxf node-#{rubber_env.node_server_version}.tar.gz
          
          # Build the binaries.
          cd node-#{rubber_env.node_server_version}
          ./configure
          make

          # Install the binaries.
          make install

          # Clean up after ourselves.
          cd ..
          rm -rf node-#{rubber_env.node_server_version}
          rm node-#{rubber_env.node_server_version}.tar.gz
        fi
      ENDSCRIPT
    end

    after "rubber:bootstrap", "rubber:node:bootstrap"

    task :bootstrap, :roles => :node do
    end

    task :start, :roles => :node do
    end

    task :stop, :roles => :node do
    end

    task :restart, :roles => :node do
      stop
      start
    end

  end
end
