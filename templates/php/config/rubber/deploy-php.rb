namespace :rubber do

  namespace :php do

    rubber.allow_optional_tasks(self)

    after "rubber:install_packages", "rubber:php:install"

    task :install, :roles => :php do
      rubber.sudo_script 'install_php', <<-ENDSCRIPT
        # Need to change cgi.fix_pathinfo=1 to cgi.fix_pathinfo=0 in /etc/php5/fpm/php.ini        
        if grep -Fxq ';cgi.fix_pathinfo=1' /etc/php5/fpm/php.ini
        then
          echo 'Replacing the ;cgi.fix_pathinfo=1 to cgi.fix_pathinfo=0 in /etc/php5/fpm/php.ini'
          sed -i.bak 's|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|g' /etc/php5/fpm/php.ini
        else
          echo 'Did not find ;cgi.fix_pathinfo=1 in /etc/php5/fpm/php.ini'
        fi
        # Need to change listen=127.0.0.1:9000 to listen=/var/run/php5-fpm.sock in /etc/php5/fpm/pool.d/www.conf
        if grep -Fxq 'listen = 127.0.0.1:9000' /etc/php5/fpm/pool.d/www.conf
        then
          echo 'Replacing the listen=127.0.0.1:9000 to listen=/var/run/php5-fpm.sock in /etc/php5/fpm/pool.d/www.conf'
          sed -i.bak 's|listen = 127.0.0.1:9000|listen = /var/run/php5-fpm.sock|g' /etc/php5/fpm/pool.d/www.conf
        else
          echo 'Did not find listen = 127.0.0.1:9000 in /etc/php5/fpm/pool.d/www.conf'
        fi
      ENDSCRIPT
    end

    after "rubber:bootstrap", "rubber:php:bootstrap"

    after "rubber:php:install", "rubber:php:restart"

    task :bootstrap, :roles => :php do
    end

    task :start, :roles => :php do
      rsudo "service php5-fpm start"
    end

    task :stop, :roles => :php do
      rsudo "service php5-fpm stop"
    end

    task :restart, :roles => :php do
      rsudo "service php5-fpm restart"
    end

  end
end
