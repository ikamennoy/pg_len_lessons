#!/bin/bash
mip=`curl -s https://ipinfo.io/json|jq .ip|sed 's/"//g'`

yc vpc network create --name testnetb
yc vpc subnet create --network-name testnetb --name subnetb --zone 'ru-central1-b' --range '10.0.130.0/24'


yc compute instance create --name va --metadata-from-file user-data=meta.yaml --create-boot-disk name=va,type=network-ssd,size=20G,auto-delete,image-folder-id=standard-images,image-family=centos-7 --memory 2G --cores 2 --hostname va --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 20 --preemptible --platform standard-v2 --network-interface subnet-name=subnetb --async 

yc compute instance create --name vd --metadata-from-file user-data=meta.yaml --create-boot-disk name=vd,type=network-ssd,size=20G,auto-delete,image-folder-id=standard-images,image-family=centos-7 --memory 2G --cores 2 --hostname vd --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 20 --preemptible --platform standard-v2 --network-interface subnet-name=subnetb --async

yc compute instance create --name vb --metadata-from-file user-data=meta.yaml --create-boot-disk name=vb,type=network-ssd,size=20G,auto-delete,image-folder-id=standard-images,image-family=centos-7 --memory 2G --cores 2 --hostname vb --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 20 --preemptible --platform standard-v2 --network-interface subnet-name=subnetb

yc compute instance add-one-to-one-nat vb --network-interface-index 0
hostip=`yc compute instance show vb --format json |  jq '.network_interfaces[0].primary_v4_address.one_to_one_nat.address'|sed 's/"//g'`

for i in `seq 1 1 100` 
do ssh -i ~/.ssh/yc_serialssh_key -o "StrictHostKeyChecking=no" uuu@$hostip whoami && break ||sleep 5s
hostip=`yc compute instance show vb --format json |  jq '.network_interfaces[0].primary_v4_address.one_to_one_nat.address'|sed 's/"//g'`
done

mv -f ~/.ssh/known_hosts{,2}
scp -i ~/.ssh/yc_serialssh_key -o "StrictHostKeyChecking=no" ~/.ssh/yc_serialssh_key uuu@$hostip:~/.ssh/id_rsa
scp -i ~/.ssh/yc_serialssh_key -o "StrictHostKeyChecking=no" consul-1.17.2-1.el7.x86_64.rpm consul-template.gz 1_run_master.sh patroni.yml 2_sub.sh uuu@$hostip:~/
echo -e "mip=$mip\nhostip=$hostip"|ssh -i ~/.ssh/yc_serialssh_key uuu@$hostip tee .env
ssh -i ~/.ssh/yc_serialssh_key uuu@$hostip <<EOF
test -f .env && source .env
sudo bash ./1_run_master.sh
EOF

