```console
id: enp6st4pg5pe1ccddpbg
created_at: "2023-10-30T16:27:12Z"
name: testnetb
default_security_group_id: enpu2fghk6ltb36kt4sh

id: e2l1nag7v61knat4i2ln
created_at: "2023-10-30T16:27:55Z"
name: subnetb
network_id: enp6st4pg5pe1ccddpbg
zone_id: ru-central1-b
v4_cidr_blocks:
  - 10.0.130.0/24

done (34s)
id: epdg7ikvlk5cgobv0tn5
created_at: "2023-10-30T16:51:00Z"
name: tu22p
zone_id: ru-central1-b
platform_id: standard-v2
resources:
  memory: "4294967296"
  cores: "2"
  core_fraction: "50"
status: RUNNING
metadata_options:
  gce_http_endpoint: ENABLED
  aws_v1_http_endpoint: ENABLED
  gce_http_token: ENABLED
  aws_v1_http_token: DISABLED
boot_disk:
  mode: READ_WRITE
  device_name: epdohc6n4v7ptjv2sm0t
  auto_delete: true
  disk_id: epdohc6n4v7ptjv2sm0t
network_interfaces:
  - index: "0"
    mac_address: d0:0d:10:3c:a9:fa
    subnet_id: e2l1nag7v61knat4i2ln
    primary_v4_address:
      address: 10.0.130.22
gpu_settings: {}
fqdn: upgtest.ru-central1.internal
scheduling_policy:
  preemptible: true
network_settings:
  type: STANDARD
placement_policy: {}

done (5s)
id: epdg7ikvlk5cgobv0tn5
created_at: "2023-10-30T16:51:00Z"
name: tu22p
zone_id: ru-central1-b
platform_id: standard-v2
resources:
  memory: "4294967296"
  cores: "2"
  core_fraction: "50"
status: RUNNING
metadata_options:
  gce_http_endpoint: ENABLED
  aws_v1_http_endpoint: ENABLED
  gce_http_token: ENABLED
  aws_v1_http_token: DISABLED
boot_disk:
  mode: READ_WRITE
  device_name: epdohc6n4v7ptjv2sm0t
  auto_delete: true
  disk_id: epdohc6n4v7ptjv2sm0t
network_interfaces:
  - index: "0"
    mac_address: d0:0d:10:3c:a9:fa
    subnet_id: e2l1nag7v61knat4i2ln
    primary_v4_address:
      address: 10.0.130.22
      one_to_one_nat:
        address: 51.250.102.180
        ip_version: IPV4
gpu_settings: {}
fqdn: upgtest.ru-central1.internal
scheduling_policy:
  preemptible: true
network_settings:
  type: STANDARD
placement_policy: {}
```
