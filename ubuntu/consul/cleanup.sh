# stop the service
sudo service consul stop

# clean up files
sudo rm -rf /var/lib/consul
sudo rm /usr/local/bin/consul
sudo rm -rf /etc/consul.d/
sudo rm /etc/init/consul.conf
sudo rm -rf /usr/share/consul

# remove the consul user
sudo deluser consul
