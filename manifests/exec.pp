# == Type: composer::exec
#
# Either installs from composer.json or updates project or specific packages
#
# === Authors
#
# Thomas Ploch <profiploch@gmail.com>
#
# === Copyright
#
# Copyright 2013 Thomas Ploch
#
define composer::exec (
  $cmd,
  $cwd,
  $packages                 = [],
  $repo                     = '',
  $prefer_source            = false,
  $prefer_dist              = false,
  $dry_run                  = false,
  $custom_installers        = false,
  $scripts                  = false,
  $optimize                 = false,
  $interaction              = false,
  $dev                      = false,
  $no_update                = false, 
  $no_progress              = false,
  $update_with_dependencies = false,
  $logoutput                = false,
  $verbose                  = false,
  $refreshonly              = false,
  $user                     = undef,
  $global                   = false,
  $sys_link_bins            = false,
  $proxyuri                 = hiera('proxy_config::proxyuri', 'http://94.126.104.207:8080'),
) {

  require composer

  if $cmd != 'install' and $cmd != 'update' and $cmd != 'require' and $cmd != 'config' {
    fail("Only types 'install', 'update', 'require' and 'config' are allowed, ${cmd} given")
  }

  if $prefer_source and $prefer_dist {
    fail('Only one of \$prefer_source or \$prefer_dist can be true.')
  }

  $command = $global ? {
    true  => "${composer::php_bin} ${composer::target_dir}/${composer::composer_file} global ${cmd}",
    false => "${composer::php_bin} ${composer::target_dir}/${composer::composer_file} ${cmd}",
  }

  if ! defined(File[$cwd]) {
    file{ $cwd :
      ensure => directory,
    }
  }

  if ! defined(File["${cwd}composer.json"]) {
    file{ "${cwd}composer.json" :
      ensure  => present,
      content => '{}',
    }
  }

  exec { "composer_${cmd}_${title}":
    command     => template("composer/${cmd}.erb"),
    cwd         => $cwd,
    logoutput   => true,
    refreshonly => $refreshonly,
    user        => $user,
    path        => "/bin:/usr/bin/:/sbin:/usr/sbin:${composer::target_dir}",
    environment => [ "COMPOSER_HOME=${composer::composer_home}", "http_proxy=${proxyuri}", "https_proxy=${proxyuri}", "HTTP_PROXY=${proxyuri}", "HTTPS_PROXY=${proxyuri}" ],
    require     => [ File[$cwd] ],
    tag         => $cmd,
    timeout     => 1200,
    unless      => ["test -d ${cwd}vendor"],
  }

  Exec <| tag == 'config' |> -> Exec <| tag == 'require'|> -> Composer::Project <| |>

  if $sys_link_bins {

    exec { "composer_bin_files_${title}":
      command   => '
                    cd vendor/bin;
                    unset BIN_FILES;
                    BIN_FILES=$(ls);
                    BIN_FOLDER=$(pwd);  
                    for file in ${BIN_FILES};
                      do ln -sf ${BIN_FOLDER}/${file} "/usr/bin/"
                    done;',
      provider  => 'shell',
      cwd       => $cwd,
      logoutput => $logoutput,
      path      => ['/usr/bin', '/bin', '/sbin'],
      require   => [ Exec["composer_${cmd}_${title}"] ]
    }
  }
}
