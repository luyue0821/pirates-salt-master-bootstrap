#!/bin/bash -ex

REGION=cn-north-1

CONFIG_PATH=s3://pirates-ops/salt-master/bootstrap/

FORMULA_HOSTNAME=pirates-formula
FORMULA_KEY=s3://pirates-ops/salt-master/keys/git-formula
FORMULA_LOCAL_KEY=/etc/salt/ssh-keys/git-formula

apt-get install python-git -y

aws s3 cp $CONFIG_PATH . --recursive --exclude "bootstrap.sh"

aws s3 cp $FORMULA_KEY $FORMULA_LOCAL_KEY --region $REGION

sed -i "s@__PIRATES_FORMULA_HOSTNAME__@$FORMULA_LOCAL_KEY@g" ssh-config
sed -i "s@__PIRATES_FORMULA_KEY__@$FORMULA_LOCAL_KEY@g" ssh-config

cat ssh-config >> ~/.ssh/config

sed -i "s@__FORMULA_HOSTNAME__@$FORMULA_HOSTNAME@g" roots.conf
cp roots.conf /etc/salt/master.d/
chmod 600 $FORMULA_LOCAL_KEY

cat known_hosts >> ~/.ssh/known_hosts

systemctl start salt-master.service
systemctl enable salt-master.service
