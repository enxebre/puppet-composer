# == Class: composer
#
# The parameters for the composer class and corresponding definitions
#
# === Parameters
#
# Document parameters here.
#
# [*target_dir*]
#   The target dir that composer should be installed to.
#   Defaults to ```/usr/local/bin```.
#
# [*composer_file*]
#   The name of the composer binary, which will reside in ```target_dir```.
#
# [*download_method*]
#   Either ```curl``` or ```wget```.
#
# [*method_package*]
#   Specific ```curl``` or ```wget``` Package.
#
# [*logoutput*]
#   If the output should be logged. Defaults to FALSE.
#
# [*tmp_path*]
#   Where the composer.phar file should be temporarily put.
#
# [*php_package*]
#   The Package name of tht PHP CLI package.
#
# [*composer_home*]
#   Folder to use as the COMPOSER_HOME environment variable. Default comes
#   from our composer::params class which derives from our own $composer_home
#   fact. The fact returns the current users $HOME environment variable.
#
# [*php_bin*]
#   The name or path of the php binary to override the default set in the
#   composer::params class.
#
# [*suhosin_enabled*]
#   If true augeas dependencies are added.
#
# === Authors
#
# Thomas Ploch <profiploch@gmail.com>
#
class composer(
  $target_dir      = $composer::params::target_dir,
  $composer_file   = $composer::params::composer_file,
  $download_method = $composer::params::download_method,
  $method_package  = $composer::params::method_package,
  $curl_package    = $composer::params::method_package,
  $wget_package    = $composer::params::method_package,
  $logoutput       = $composer::params::logoutput,
  $tmp_path        = $composer::params::tmp_path,
  $php_package     = $composer::params::php_package,
  $composer_home   = $composer::params::composer_home,
  $php_bin         = $composer::params::php_bin,
  $suhosin_enabled = $composer::params::suhosin_enabled,
  $projects        = hiera_hash('composer::projects', {}),
  $execs           = hiera_hash('composer::execs', {}),
  $proxyuri        = hiera('proxy_config::proxyuri', 'http://94.126.104.207:8080'),
  $version         = '1.0.0-alpha8',
  $source          = 'e77435cd0c984e2031d915a6b42648e7b284dd5c',
  $timeout         = hiera('composer::timeout', 300),
  ) inherits composer::params {

  warning('The $curl_package parameter is deprecated so users of this module will get failures when they update if they have these set')
  warning('The $wget_package parameter is deprecated so users of this module will get failures when they update if they have these set')

  # Generic settings for exec resources.
  if $proxyuri {
    Exec { environment => [ "COMPOSER_HOME=${composer::composer_home}", "http_proxy=${proxyuri}", "https_proxy=${proxyuri}", "HTTP_PROXY=${proxyuri}", "HTTPS_PROXY=${proxyuri}" ] }
  }
  else {
    Exec { environment => [ "COMPOSER_HOME=${composer::composer_home}" ] }
  }

  Exec { timeout => $timeout }

  case $download_method {
    'curl': {
      $download_command = "curl -sS -x ${proxyuri} http://getcomposer.org/installer | php -- --version=${version}"
    }
    'wget': {
      $download_command = "wget --no-check-certificate http://getcomposer.org/download/${version}/composer.phar -O composer.phar"
    }
    default: {
      fail("The param download_method ${download_method} is not valid. Please set download_method to curl or wget.")
    }
  }

  if !empty($source) {

    # download composer once we have all requirements for
    # it working properly.
    class { 'composer::dependencies': 
      download_method => $composer::download_method,
      method_package  => $composer::method_package,
      php_package     => $composer::php_package,
      suhosin_enabled => $composer::suhosin_enabled,
    }
    ->
    # check if directory exists
		file { "${tmp_path}/composer-source":
		  ensure => directory,
		}
		->
    vcsrepo { "${tmp_path}/composer-source" : 
	    ensure   => present,
	    provider => git,
	    source   => 'https://github.com/composer/composer.git',
	  }
	  -> 
	  exec { 'checkout-source' :
	    command => "git checkout ${source};",
      cwd     => "${tmp_path}/composer-source",
      path      => "/bin:/usr/bin/:/sbin:/usr/sbin:${target_dir}",
      logoutput   => true,
	  }
	  ->
    exec { 'download_composer_installer':
      command => "curl -x '${proxyuri}' -sS https://getcomposer.org/installer | php",
      cwd     => "${tmp_path}",
      path      => "/bin:/usr/bin/:/sbin:/usr/sbin:${target_dir}",
      logoutput   => true,
    }
    ->
    exec { 'install_composer_dependencies':
      command => "php ../composer.phar install -q --no-dev",
      cwd     => "${tmp_path}/composer-source",
      path    => "/bin:/usr/bin/:/sbin:/usr/sbin:${target_dir}",
      logoutput   => true,
    }
    ->
	  exec { 'install_composer':
	    command => "php -d phar.readonly=0 bin/compile;mv composer.phar ../",
	    cwd     => "${tmp_path}/composer-source",
	    path      => "/bin:/usr/bin/:/sbin:/usr/sbin:${target_dir}",
	    logoutput   => true,
	  }
  }
  else {

	  # download composer once we have all requirements for
	  # it working properly.
	  class { 'composer::dependencies': 
      download_method => $composer::download_method,
      method_package  => $composer::method_package,
      php_package     => $composer::php_package,
      suhosin_enabled => $composer::suhosin_enabled,
	  }
	  ->
	  exec { 'install_composer':
	    command   => $download_command,
	    cwd       => $tmp_path,
	    creates   => "${tmp_path}/composer.phar",
	    logoutput => true,
	    path      => "/bin:/usr/bin/:/sbin:/usr/sbin:${target_dir}",
	  }    
  }

  # check if directory exists
  file { $target_dir:
    ensure => directory,
  }

  # move file to target_dir
  file { "${target_dir}/${composer_file}":
    ensure  => present,
    source  => "${tmp_path}/composer.phar",
    require => [ Exec['install_composer'], File[$target_dir] ],
    mode    => 0755,
  }

  if $projects or $execs {
    class {'composer::project_factory' :
      projects => $projects,
      execs    => $execs,
    }
  }
}
