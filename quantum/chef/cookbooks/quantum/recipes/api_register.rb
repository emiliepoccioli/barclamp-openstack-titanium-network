# Copyright 2013 Dell, Inc.
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

# Added for VIP - sak
my_admin_host = node[:haproxy][:admin_ip]
my_public_host = node[:haproxy][:public_ip]
server_root_password = node["percona"]["server_root_password"]

Chef::Log.info("============================================")
Chef::Log.info("admin vip at #{my_admin_host}")
Chef::Log.info("public vip at #{my_public_host}")
Chef::Log.info("============================================")
# end of change

# commented out for VIP -sak
=begin
my_admin_host = node[:fqdn]
# For the public endpoint, we prefer the public name. If not set, then we
# use the IP address except for SSL, where we always prefer a hostname
# (for certificate validation).
my_public_host = node[:crowbar][:public_name]
if my_public_host.nil? or my_public_host.empty?
  unless node[:quantum][:api][:protocol] == "https"
    my_public_host = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
  else
    my_public_host = 'public.'+node[:fqdn]
  end
end
=end
# end of change

api_port = node["quantum"]["api"]["service_port"]
quantum_protocol = node["quantum"]["api"]["protocol"]

env_filter = " AND keystone_config_environment:keystone-config-#{node[:quantum][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

# use VIP - sak
#keystone_host = keystone[:fqdn]
#keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_host = my_admin_host
# end of change
keystone_token = keystone["keystone"]["service"]["token"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["quantum"]["service_user"]
keystone_service_password = node["quantum"]["service_password"]
admin_username = keystone["keystone"]["admin"]["username"] rescue nil
admin_password = keystone["keystone"]["admin"]["password"] rescue nil

Chef::Log.info("Keystone server found at #{keystone_host}")
Chef::Log.info("Keystone token:            #{keystone_token}")
Chef::Log.info("Keystone service port:     #{keystone_service_port}")
Chef::Log.info("Keystone admin port:       #{keystone_admin_port}")
Chef::Log.info("Keystone service tenant:   #{keystone_service_tenant}")
Chef::Log.info("Keystone service user:     #{keystone_service_user}")
Chef::Log.info("Keystone service password: #{keystone_service_password}")
Chef::Log.info("Keystone admin username:   #{admin_username}")
Chef::Log.info("Keystone admin password    #{admin_password}")

keystone_register "quantum api wakeup keystone" do
  #protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  action :wakeup
end

keystone_register "register quantum user" do
  #protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  user_password keystone_service_password
  tenant_name keystone_service_tenant
  action :add_user
end

keystone_register "give quantum user access" do
  #protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "admin"
  action :add_access
end

keystone_register "register quantum service" do
  #protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  service_name "quantum"
  service_type "network"
  service_description "Openstack Quantum Service"
  action :add_service
end

keystone_register "register quantum endpoint" do
  #protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  endpoint_service "quantum"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{quantum_protocol}://#{my_public_host}:#{api_port}/"
  endpoint_adminURL "#{quantum_protocol}://#{my_admin_host}:#{api_port}/"
  endpoint_internalURL "#{quantum_protocol}://#{my_admin_host}:#{api_port}/"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end


