# Puppet manifest for my PHP dev machine

# Edit local /etc/hosts files to resolve some hostnames used on your application.
host { 'localhost':
    ensure => 'present',
    target => '/etc/hosts',
    ip => '127.0.0.1',
    host_aliases => ['memcache1']
}

# Configuration to use xdebug.
file { "/etc/php.d/xdebug.ini":
	source => "/vagrant/files/templates/xdebug/xdebug.ini",
	owner => root, group => root, mode => 644, replace => true, ensure => present,
	require => Package["php-pecl-xdebug"],
    notify  => Service["httpd"]
}

# Adding EPEL repo. We'll use later to install Redis class.
class { 'epel': }

# Miscellaneous packages.
$misc_packages = ['vim-enhanced','telnet','zip','unzip','git','screen','libssh2','libssh2-devel', 'gcc', 'gcc-c++', 'autoconf', 'automake']
package { $misc_packages: ensure => latest }
class { "ntp": package_ensure => true }

# Iptables (Firewall) package and rules to allow ssh, http, https and dns services.
class iptables {
	package { "iptables":
		ensure => present
	}

	service { "iptables":
		require => Package["iptables"],
		hasstatus => true,
		status => "true",
		hasrestart => false,
	}

	file { "/etc/sysconfig/iptables":
		owner   => "root",
		group   => "root",
		mode    => 600,
		replace => true,
		ensure  => present,
		source  => "/vagrant/files/templates/iptables.txt",
		require => Package["iptables"],
		notify  => Service["iptables"],
	}
}
class { 'iptables': }

class { 'apache':
	sendfile		=> 'off'
}

apache::vhost { 'centos.local':
    priority        => '1',
    port            => '80',
    serveraliases   => ['www.centos.local',],
	docroot         => '/var/www',
    docroot_owner	=> 'vagrant',
    docroot_group	=> 'vagrant',
}

apache::vhost { 'project.local':
    serveraliases   => ['*.project.local'],
    priority        => '5',
    port            => '80',
    template    => '/vagrant/files/templates/apache/vhost-project.conf.erb',
    docroot         => '/www',
    docroot_owner => 'vagrant',
    docroot_group => 'vagrant',
}

# MySQL packages and some configuration to automatically create a new database.
class { 'mysql': }

class { 'mysql::server':
	config_hash => {
#        root_password     => '---',
		log_error 		=> '/logs/mysql',
		default_engine	=> 'InnoDB'
	}
}

Database {
	require => [ Class['mysql'] , Class['mysql::server'] ],
}

Database_user {
	require => [ Class['mysql'] , Class['mysql::server'] ],
}

database { 'projectdb':
  ensure => 'present',
  charset => 'utf8',
}

database_user { 'project_db_user@localhost':
  password_hash => mysql_password('123456')
}

database_grant { 'project_db_user@localhost/projectdb':
  privileges => ['all'],
  require => [ Database_user['project_db_user@localhost'], Database['projectdb'] ]
}

$additional_mysql_packages = [ "mysql-devel", "mysql-libs" ]
package { $additional_mysql_packages: ensure => present }

# Memcached.

class { 'memcached':
	max_memory => 2048
}

# PHP useful packages. Pending TO-DO: Personalize some modules and php.ini directy on Puppet recipe.
php::ini {
	'/etc/php.ini':
        display_errors	=> 'On',
        short_open_tag	=> 'On',
        memory_limit	=> '512M',
		date_timezone	=> 'Europe/Madrid',
		html_errors		=> 'On'
}
include php::cli
include php::mod_php5
php::module { [ 'devel', 'pear', 'mysql', 'mbstring', 'xml', 'gd', 'tidy', 'pecl-apc', 'pecl-memcached', 'soap', 'pecl-xdebug', 'mcrypt' ]: }
php::module { 'pecl-ssh2':
	require => [ Package['libssh2'], Package['libssh2-devel'] ]
}