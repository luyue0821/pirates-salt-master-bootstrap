#!/bin/bash -e

# TODO For debug purpose.
echo "log_level: debug" > /etc/salt/master.d/log.conf

REGION=cn-north-1

CONFIG_PATH=s3://pirates-ops/salt-master/bootstrap/

FORMULA_HOSTNAME=pirates-formula
FORMULA_KEY=s3://pirates-ops/salt-master/keys/git-formula
FORMULA_LOCAL_KEY=/etc/salt/ssh-keys/git-formula

PILLAR_HOSTNAME=pirates-pillar
PILLAR_KEY=s3://pirates-ops/salt-master/keys/git-pillar
PILLAR_LOCAL_KEY=/etc/salt/ssh-keys/git-pillar

if [ "$#" -lt 1 ]; then
  echo "Illegal number of parameters. Need to pass in env parameter as pillar root."
  exit 1
fi
pillar_root=$1
echo pillar_root=$pillar_root

apt-get update
echo Installing python-git at $(date)...
apt-get install python-git -y

echo Downloading bootstrap config at $(date)...
aws s3 cp $CONFIG_PATH . --recursive --exclude "bootstrap.sh" --region $REGION

echo Configurating repos at $(date)...
echo Downloading formula git repo key...
aws s3 cp $FORMULA_KEY $FORMULA_LOCAL_KEY --region $REGION
chmod 600 $FORMULA_LOCAL_KEY

echo Downloading pillar git repo key...
aws s3 cp $PILLAR_KEY $PILLAR_LOCAL_KEY --region $REGION
chmod 600 $PILLAR_LOCAL_KEY

echo Doing ssh configuration...
sed -i "s@__PIRATES_FORMULA_HOSTNAME__@$FORMULA_HOSTNAME@g" ssh-config
sed -i "s@__PIRATES_FORMULA_KEY__@$FORMULA_LOCAL_KEY@g" ssh-config

sed -i "s@__PIRATES_PILLAR_HOSTNAME__@$PILLAR_HOSTNAME@g" ssh-config
sed -i "s@__PIRATES_PILLAR_KEY__@$PILLAR_LOCAL_KEY@g" ssh-config

cat ssh-config >> ~/.ssh/config

echo Configurating salt-master file server at $(date)...
sed -i "s@__FORMULA_HOSTNAME__@$FORMULA_HOSTNAME@g" fileserver.conf
sed -i "s@__PILLAR_HOSTNAME__@$PILLAR_HOSTNAME@g" fileserver.conf
sed -i "s@__PILLAR_ROOT__@$pillar_root@g" fileserver.conf
cp fileserver.conf /etc/salt/master.d/

echo Adding known hosts at $(date)...
cat known_hosts >> ~/.ssh/known_hosts

echo Setting roles:master grains at $(date)...
salt-call grains.append roles master --local

echo fileserver.update at $(date)...
salt-run fileserver.update
echo git_pillar.update at $(date)...
salt-run git_pillar.update

echo Applying master state at $(date)...
salt-run salt.cmd state.apply master with_pillar=True

echo Starting salt-master service at $(date)...
systemctl start salt-master.service
systemctl enable salt-master.service

echo Starting salt-api service at $(date)...
systemctl start salt-api.service
systemctl enable salt-api.service

echo Configurating salt-minion on master at $(date)...
echo "master: localhost" |sudo tee /etc/salt/minion.d/master.conf
minion_id=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)
echo "$minion_id" |sudo tee /etc/salt/minion_id

salt-key --gen-keys=$minion_id
cp $minion_id.pub /etc/salt/pki/master/minions/$minion_id
mv $minion_id.pub /etc/salt/pki/minion/minion.pub
mv $minion_id.pem /etc/salt/pki/minion/minion.pem

echo Starting salt-minion.service at $(date)...
systemctl start salt-minion
