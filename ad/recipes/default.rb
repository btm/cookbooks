#
# Author:: Bryan McLellan <btm@loftninjas.org>
# Cookbook Name:: ad
# Recipe:: default
#
# Copyright 2008, Bryan McLellan
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package "krb5-user"
package "libpam-krb5"

template "/etc/krb5.conf" do
  source "krb5.conf.erb"
  mode 0644
  owner "root"
  group "root"
  variables(
    :krb5_realm => node[:krb5_realm],
    :domain_controllers => node[:domain_controllers]
  )
end

# winbind and nscd are exclusive and both perform caching
package("nscd") { action :remove }
package "winbind"

template "/etc/samba/smb.conf" do
  source "smb.conf.erb"
  mode 0644
  owner "root"
  group "root"
  variables(
    :krb5_realm => node[:krb5_realm],
    :ad_workgroup => node[:ad_workgroup]
  )
end

execute "initialize-kerberos" do
  command "echo #{@node[:ad_auth_domain_password]} | kinit #{@node[:ad_auth_domain_user]}@#{@node[:krb5_realm]}"
  not_if { File.exists?("/tmp/krb5cc_0") }
end

# join the computer to the domain
execute "net-ads-join" do
  command "net ads join -U #{@node[:ad_auth_domain_user]}%'#{@node[:ad_auth_domain_password]}'"
  not_if "net ads testjoin -P"
end

service "winbind" do
  supports :restart => true, :status => true
  action [ :enable, :restart ]
end

pam_common_files = %w{common-auth common-account common-session common-password}

pam_common_files.each do |file|
  remote_file "/etc/pam.d/#{file}" do
    source file
    mode 0644
  end
end

remote_file "/etc/nsswitch.conf" do
  source "nsswitch.conf"
  mode 0644
end

