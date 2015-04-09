Kitchen / Docker / Puppet
===================

After several years trying to make its own configuration management tool, my organization has decided to look at the side of **Puppetlabs**.
The model described is a hierarchical tree whose **Role-Based Access Control**[^RBAC] will manage by **Git** hooks. This is the masterless mode was selected (no SPOF, finer control configuration applied to servers).

**Fabric** will surely be used to orchestrate the push towards the nodes.

Prerequisites
=============

- [KitchenCI](http://kitchen.ci/) 
- Ruby > 2.0
- Bundler

Get cooking !
=============

```
$> mkdir kitchen-docker-puppet-example
$> cd kitchen-docker-puppet-example
$> git init
$> kitchen init --driver=kitchen-docker --create-gemfile
```

Bring puppets !
===============

...

```
$> echo 'gem "kitchen-puppet"' >> Gemfile
$> echo 'gem "puppet"' >> Gemfile
$> echo 'gem "librarian-puppet"' >> Gemfile
```
...
```
$> cat << FIN >> hiera.yml
:backends:
  - yaml
:yaml:
  :datadir: /var/lib/hiera
:hierarchy:
  - node/classes
  - origin/main
  - ntp
FIN
```
...
```
$> mkdir manifests
$> cat << FIN >> manifests/site.pp
#hiera_include('classes')
class { '::ntp':
  servers => [ '0.pool.ntp.org', '1.pool.ntp.org' ],
}
FIN
```
...
```
$> librarian-puppet init
$> cat << FIN >> Puppetfile
#!/usr/bin/env ruby
#^syntax detection

forge "https://forgeapi.puppetlabs.com"

# use dependencies defined in Modulefile
mod "puppetlabs-ntp"
mod 'puppetlabs-stdlib'
FIN

$> librarian-puppet install
```

Cook with container
===================

...
```
$> cat << FIN >> centos-latest-dockerfile
FROM centos:latest
RUN yum clean all
RUN yum install -y sudo openssh-server openssh-clients which curl htop
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN mkdir -p /var/run/sshd
RUN useradd -d /home/kitchen -m -s /bin/bash cdelgehier
RUN echo kitchen:kitchen | chpasswd
RUN echo 'kitchen ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
FIN
```

Setup
=====

Now we have to update the kitchen.yml file with puppet specific options from the kitchen-puppet gem See [kitchen-puppet](https://github.com/neillturner/kitchen-puppet) and [provisioner options](https://github.com/neillturner/kitchen-puppet/blob/master/provisioner_options.md) for details.
```
$> cat << FIN > .kitchen.yml
driver:
  name: docker

provisioner:
  name: puppet_apply
  manifests_path: manifests
  modules_path: modules
  hiera_data_path: hieradata
  #hiera_config_path: hiera.yml
  #resolve_with_librarian_puppet: true

platforms:
  - name: centos-latest
    driver_config:
      image: centos:latest
      platform: centos 
      use_cache: true
      dockerfile: centos-latest-dockerfile
      #socket: <%= ENV['DOCKER_HOST'] %>

suites:
  - name: default
    manifest: site.pp
FIN
```

Tests
=====

[Bats](https://github.com/sstephenson/bats)
----------
```
$> install -d test/integration/default/bats
$> cat << FIN >> test/integration/default/bats/ntp_installed.bats
#!/usr/bin/env bats

@test "ntp rpm found" {
  run rpm -qa ntp
  [ "$status" -eq 0 ]
}
FIN
```

[Serverspec](http://serverspec.org/)
----------

```
$> install -d test/integration/default/serverspec
$> cat << FIN >> test/integration/default/serverspec/ntp_daemon_spec.rb 
require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package('ntp'), :if => os[:family] == 'redhat' do
  it { should be_installed }
end

describe file('/etc/ntp.conf') do
  it { should be_file }
  its(:content) { should match /server 0.pool.ntp.org prefer/ }
  its(:content) { should match /server 1.pool.ntp.org/ }
end

describe "Ntp Daemon" do
  it "has a running service of ntpd" do
    expect(service("ntpd")).to be_running
  end
end
FIN
```

<i class="icon-cog"></i>Here We Go! 
=====
...
```
$> bundle install
$> kitchen list
$> kitchen converge default-centos-latest
$> kitchen verify
```


[^RBAC]: [Role-Based Access Control](http://en.wikipedia.org/wiki/Role-based_access_control)  is an approach to restricting system access to authorized users




