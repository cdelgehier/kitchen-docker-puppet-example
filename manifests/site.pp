#hiera_include('classes')
class { '::ntp':
  servers => [ '0.pool.ntp.org prefer', '1.pool.ntp.org' ],
}

