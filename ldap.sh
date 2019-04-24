#!/bin/zsh


echo 'Enter dc'
read dc1
echo 'Enter dc'
read dc2
echo 'Enter LDAP server'
read server
pacman -S openldap nss-pam-ldapd
sed -i "s/#BASE\tdc=example,dc=com/BASE\tdc=$dc1,dc=$dc2/" /etc/openldap/ldap.conf
sed -i "s/#URI\tldap:\/\/ldap.example.com ldap:\/\/ldap-master.example.com:666/URI\tldap:\/\/$server/" /etc/openldap/ldap.conf
sed -i "s/passwd: files mymachines systemd/passwd: files ldap mymachines systemd/" /etc/nsswitch.conf
sed -i "s/group: files mymachines systemd/group: files ldap mymachines systemd/" /etc/nsswitch.conf
sed -i "s/shadow: files/shadow: files ldap/" /etc/nsswitch.conf
sed -i "s/base dc=example,dc=com/base dc=$dc1,dc=$dc2/" /etc/nslcd.conf
sed -i "s/uri ldap:\/\/127.0.0.1\//uri ldap:\/\/$server\//" /etc/nslcd.conf
systemctl start nslcd
systemctl enable nslcd
sed -i "/auth      required  pam_unix.so/i auth      sufficient  pam_ldap.so" /etc/pam.d/system-auth
sed -i "/account   required  pam_unix.so/i account   sufficient  pam_ldap.so" /etc/pam.d/system-auth
sed -i "/password  required  pam_unix.so/i password  sufficient  pam_ldap.so" /etc/pam.d/system-auth
sed -i "/session   required  pam_unix.so/a session   optional  pam_ldap.so" /etc/pam.d/system-auth
sed -i "/auth\t\tsufficient\tpam_rootok.so/i auth\t\tsufficient\tpam_ldap.so" /etc/pam.d/su
sed -i "/account\t\trequired\tpam_unix.so/i account\t\tsufficient\tpam_ldap.so" /etc/pam.d/su
sed -i "/session\t\trequired\tpam_unix.so/i session\t\tsufficient\tpam_ldap.so" /etc/pam.d/su
sed -i "s/auth\t\trequired\tpam_unix.so/auth\t\trequired\tpam_unix.so use_first_pass/" /etc/pam.d/su
sed -i "/auth\t\tsufficient\tpam_rootok.so/i auth\t\tsufficient\tpam_ldap.so" /etc/pam.d/su-l
sed -i "/account\t\trequired\tpam_unix.so/i account\t\tsufficient\tpam_ldap.so" /etc/pam.d/su-l
sed -i "/session\t\trequired\tpam_unix.so/i session\t\tsufficient\tpam_ldap.so" /etc/pam.d/su-l
sed -i "s/auth\t\trequired\tpam_unix.so/auth\t\trequired\tpam_unix.so use_first_pass/" /etc/pam.d/su-l
sed -i "/session    required   pam_env.so/a session    required   pam_mkhomedir.so skel=/etc/skel umask=0022" /etc/pam.d/system-login
