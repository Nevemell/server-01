sudo apt-get update sudo apt-get install curl git vim htop
sudo apt-get update && sudo apt-get install curl git vim htop
sudo apt-get install easy-rsa
sudo vim /etc/ssh/sshd_config
sudo systemctl restart ssh
sudo iptables -F
sudo iptables -X
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
# Разрешить установленный трафик
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
# Если OpenVPN
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
# ICMP (опционально)
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
mkdir ~/easy-rsa
ды
ls
cd easy-rsa/
mkdir ~/easy-rsa
mkdir ~/easy-rsa1
ls
mkdir ./easy-rsa1
ls
rm easy-rsa1/
ls
rm easy-rsa1
rm -r easy-rsa1
ls
clear
cd ..
ls
cd ..
ls
cd sysadmin/
ls
rm -r easy-rsa1/
ls
vim setup_ca.sh
sudo chmod +x setup_ca.sh
./setup_ca.sh 
ls
vim setup_ca.sh 
./setup_ca.sh 
vim setup_ca.sh 
./setup_ca.sh 
vim setup_ca.sh 
echo ~
echo $HOME
which sh
which bash
cd easy-rsa/
cd ~
cd easy-rsa/
cd ~
cd /
cd ~/easy-rsa/
vim setup_ca.sh 
cd `

q
cd ~
vim setup_ca.sh 
./setup_ca.sh 
vim setup_ca.sh 
./setup_ca.sh 
ls
vim setup_ca.sh 
./setup_ca.sh 
vim setup_ca.sh 
./setup_ca.sh 
ls
vim setup_ca.sh 
clear
sudo apt-get update
sudo apt-get install ssmtp
sudo vim /etc/ssmtp/ssmtp.conf
sudo vim /etc/ssmtp/revaliases
sudo mv /usr/sbin/sendmail /usr/sbin/sendmail.orig
sudo ln -s /usr/sbin/ssmtp /usr/sbin/sendmail
echo test | mail -v -s "testing ssmtp" адрес@получателя
sudo apt-get install mailutils
echo test | mail -v -s "testing ssmtp" адрес@получателя
echo test | mail -s "testing ssmtp" адрес@получателя
echo test | mail -s "testing ssmtp" artem.yaksuihn007@gmail.com
cat setup_ca.sh | mail artem.yaksuihn007@gmail.com
ls
./setup_ca.sh
ls /home/sysadmin/
rm -r easy
ls
./setup_ca.sh
ls
vim setup_ca.sh
./setup_ca.sh
rm -r easy
ls
./setup_ca.sh
ls easy
cat easy/text.txt 
rm -r easy
ls
vim setup_ca.sh
./setup_ca.sh
ls
ls easy
cat easy/text.txt 
rm -r easy
ls
clear
vim setup_ca.sh 
sudo ./setup_ca.sh 
ls
ls easy-rsa/
vim setup_ca.sh 
ls
sudo ./setup_ca.sh 
ls easy-rsa/
sudo ./setup_ca.sh 
vim setup_ca.sh 
sudo ./setup_ca.sh 
ls
ls easy-rsa/
sudo ls easy-rsa/
ls /root/
sudo ls /root/
sudo ls /root/easy-rsa
sudo vim /root/easy-rsa/var
sudo vim /root/easy-rsa/vars
vim setup_ca.sh 
ls
rm -r easy-rsa/
ls
sudo ./setup_ca.sh 
vim setup_ca.sh 
sudo ./setup_ca.sh 
ls 
vim setup_ca.sh 
sudo ./setup_ca.sh ea
sudo ./setup_ca.sh 
./setup_ca.sh 
ls
ls easy-rsa/
vim easy-rsa/vars
vim easy-rsa/vars.example 
vim setup_ca.sh 
./setup_ca.sh 
ls
rm -r easy-rsa/
ls
./setup_ca.sh 
vim setup_ca.sh 
rm -r easy-rsa/
./setup_ca.sh 
ls easy-rsa/
vim easy-rsa/vars
touch ttt
ls
rm ttt 
vim setup_ca.sh 
rm -r easy-rsa/
ls
./setup_ca.sh 
ls easy-rsa/
vim easy-rsa/vars
vim easy-rsa/vars.example 
rm -r easy-rsa/
vim setup_ca.sh 
ls
clear
./setup_ca.sh 
ls
ls easy-rsa/
ls easy-rsa/va
vim easy-rsa/vars
ls easy-rsa/pki/private/
ls easy-rsa/pki/
clear
vim setup_ca.sh 
mkdir easy-rsa-ca
ls
cd easy-rsa-ca/
cp ../setup_ca.sh 
cp ../setup_ca.sh ./
ls
sudo vim .bashrc
cd ..
sudo vim .bashrc
source .bashrc
cd easy-rsa-ca/
dh_make --indep --createorig
ls
sudo dh_make --indep --createorig
sudo apt-get install dh-make devscripts
dh_make --indep --createorig
ls
echo $DEBFULLNAME
echo DEBEMAIL
echo $DEBEMAIL
ls
dh_make --indep --createorig
cd ..
ls
rm -r easy-rsa-ca/
ls
mkdir easy_rsa_ca-0.1
ls
cd easy_rsa_ca-0.1/
dh_make --indep --createorig
dh_make --indep --createorig | mail artem.yaksuihn007@gmail.com
cd ..
rm -r easy_rsa_ca-0.1/
ls
mkdir easy-rsa-ca-0.1
cp setup_ca.sh easy-rsa-ca-0.1/
ls
cd easy-rsa-ca-0.1/
ls
dh_make --indep --createorig
ls
clear
ls debian/
touch debian/install
vim debian/install 
ls
vim debian/install 
echo $HOME
vim debian/install 
ls /home
cd easy-rsa-ca-0.1/
ls
ls debian/
rm *.ex
rm -r *.ex
sudo rm -r *.ex
rm debian/*.ex
ls debian/
rm debian/README.*
ls debian/
vim debian/changelog 
ls debian/
vim debian/control 
cd easy-rsa-ca-0.1/debian/
ls
debuild -us -uc
ls ../..
clear
cd ~
ls
cd easy-rsa
ls
clear
ls
vim vars
clear
ls pki/
ls pki/private/
sudo apt-get install git
sudo apt-get update 
sudo apt-get install git
man git
sudo git --version
sudo apt install git
git config --list
sudo git config --list
git config --global user.name "Nevemell"
sudo git config --list
sudo git config --global user.name "Nevemell"
sudo git config --global user.email "artem.yaksuihn007@gmail.com"
sudo git config --list
cd /
ls
sudo git init
git add /
git add / | mail artem.yaksuihn007@gmail.com
git config --global init.defaultBranch server-01
sudo git config --list
git add .
git config --global --add save.directory /
git init server-01
sudo git init server-01
cd /home/sysadmin/
ls
mkdir config-repo
ls
cd config-repo/
ls
cd ..
ls
mkdir ../config-repo
sudo mkdir ../config-repo
ls ..
cd ../config-repo/
ls
git init
sudo git init
ln -s /home/sysadmin sysadmin
sudo ln -s /home/sysadmin sysadmin
ls
sudo git add .
git branch
cd ../config-repo/
git branch
sudo git branch
sudo git branch -a
git commit -m "Setting up an authentication center"
sudo git config --global -add safe.directory /home/config-repo
git commit -m "Setting up an authentication center"
git commit -m "Setting up an authentication center" | mail artem.yaksuihn007@gmail.com
git commit -m "Setting up an authentication center"
git config --global --add safe.directory /home/config-repo
git add
git add .
sudo git add .
sudo git commit
sudo git branch
sudo git branch -a
sudo git commit
