class gearman(
  $ensure = 'present',
  $backlog = $gearman::params::backlog,
  $job_retries = $gearman::params::job_retries,
  $port = $gearman::params::port,
  $listen = $gearman::params::listen,
  $threads = $gearman::params::threads,
  $maxfiles = $gearman::params::maxfiles,
  $worker_wakeup = $gearman::params::worker_wakeup,
  $log_file = undef,
  $verbose = undef,
  $queue_type = undef,
  $queue_params = undef,
  $disable_limits_module = false,
  $config_file = $gearman::params::config_file,
  $config_file_template = $gearman::params::config_file_template,
  $autoupgrade = false,
  $package_name = $gearman::params::package_name,
  $service_manage = true,
  $service_ensure = 'running',
  $service_name = $gearman::params::service_name,
  $service_enable = true,
  $service_hasstatus = false,
  $service_hasrestart = true,
  $manage_service_file = false,
  $service_file = $gearman::params::service_file,
  $service_file_template = $gearman::params::service_file_template,
  $round_robin = false,
  $epel_class = $gearman::params::epel_class,
  $delete_initd = false,
) inherits gearman::params {

  case $ensure {
    present: {
      if $autoupgrade == true {
        $package_ensure = 'latest'
      } else {
        $package_ensure = 'present'
      }

      case $service_ensure {
        running, stopped: {
          $service_ensure_real = $service_ensure
        }
        default: {
          fail('service_ensure parameter must be running or stopped')
        }
      }
    }
    absent: {
      $package_ensure = 'absent'
      $service_ensure_real = 'stopped'
    }
    default: {
      fail('ensure parameter must be present or absent')
    }
  }

  if $::osfamily == 'RedHat' {
    if ! defined(Class[$epel_class]) {
      include $epel_class
    }
    $require_epel = Class[$epel_class]
  } else {
    $require_epel = undef
  }

  package { $package_name:
    ensure  => $package_ensure,
    require => $require_epel,
  }

  file { $config_file:
    ensure  => $ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${module_name}/${config_file_template}"),
    require => Package[$package_name],
  }

  if $disable_limits_module == false {
    if $maxfiles > $gearman::params::maxfiles {
      limits::limits { "${gearman::params::user}_nofiles":
        ensure     => present,
        user       => $gearman::params::user,
        limit_type => 'nofile',
        hard       => $maxfiles,
        soft       => $maxfiles,
      }
    }
  }

  # the upstart file on ubuntu ignores /etc/defaults/gearman-job-server
  # see https://bugs.launchpad.net/ubuntu/+source/gearmand/+bug/1260830
  if $manage_service_file == true {

    debug ( "${service_file}, ${service_file_template}" )

    file { $service_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template($service_file_template),
      require => Package[$package_name],
    }
  }

  # this may be needed on ubuntu where both an upstart script
  # and /etc/init.d/ scripts are present and competing
  if $delete_initd == true {
    file { "/etc/init.d/${service_name}":
      ensure => absent,
    }
  }

  if $service_manage == true {
    service { $service_name:
      ensure     => $service_ensure_real,
      enable     => $service_enable,
      hasstatus  => $service_hasstatus,
      hasrestart => $service_hasrestart,
      require    => File[$config_file],
      subscribe  => File[$config_file, $service_file],
    }
  }
}
