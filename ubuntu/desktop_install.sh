#!/bin/bash
#
# Script to bootstrap a Linux Desktop in AWS
# from AWS provided Ubuntu 19.10 AMI
#

# Determine OS Type
OSTYPE=$(head -1 /etc/os-release | awk -F"=" '{print $2}' | tr -d '"')

# Set OS and USER variables
if [ "${OSTYPE}" = "Ubuntu" ]; then
    OS="ubuntu"
    USER="ubuntu"
    echo "OS Type is ${OS}"
else
    echo "OS Type not Recognized"
    exit 1
fi

echo "##### updating apt repository #####"
apt-get update

echo "##### upgrade all installed packages #####"
apt-get -y upgrade

echo "##### Installing ubuntu-desktop packages #####"
apt-get -y install ubuntu-desktop  

echo "##### Installing build-essential packages #####"
apt-get -y install build-essential  

echo "##### Installing xrdp package for Ubuntu #####"
apt-get -y install xrdp

# Run ubuntu specific tasks

# In order for an instance to boot from an AMI
# created after running in this script, this file
# must be present:
# /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
# The file should be empty
echo "##### Creating managed-devices.conf #####"
touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

# Install Gnome Tewak Tool
echo "##### Installing gnome-tweak-tool package #####"
apt-get -y install gnome-tweak-tool

# Check to see if Xwrapper.config exists
echo "##### Checking to see if XWrapper.config exists #####"
if [ -f /etc/X11/Xwrapper.config ]; then  
    echo "##### Xwrapper.config exists #####"   
    # Update XWrapper.config to allow users to connect via RDP
    echo "##### Updating Xwrapper.config #####"
    sed -i 's/allowed_users=console/allowed_users=anybody/' /etc/X11/Xwrapper.config
else
    echo "##### Xwrapper.config does not exist #####"
fi

# Update color manager config.  Do not check for existence of file first
# create it regardless.
echo "##### Updating Color Manager config #####"
bash -c "cat >/etc/polkit-1/localauthority/50-local.d/45-allow.colord.pkla" <<EOF
    [Allow Colord all Users]
    Identity=unix-user:*
    Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
    ResultAny=no
    ResultInactive=no
    ResultActive=yes
EOF

# Configure GNOME shell extenstions for dock
# commented out as this is not working in Ubuntu 19.10
#echo "##### Updating GNOME shell extenstion for dock #####"
#gnome-shell-extension-tool -e ubuntu-dock@ubuntu.com

# Configure GNOME shell extenstions for app indicators
# commented out as this is not working in Ubuntu 19.10
#echo "##### Updating GNOME shell extenstion for app indicators #####"
#gnome-shell-extension-tool -e ubuntu-appindicators@ubuntu.com

# Update host firewalls to allow 3389
echo "##### Modifying firewall to allow port 3389 #####"
ufw allow 3389/tcp

# Start XRDP on boot
echo "##### Enableing xrdp on system boot #####"
systemctl enable xrdp

# Install JDK 11
echo "##### Installing OpenJDK 11 #####"
apt-get -y install openjdk-11-jdk

# Install python 2.7 for backwards compatability
echo "##### Installing Python #####"
apt-get -y install python

# Install Google Chrome
# Installing with apt-get
echo "##### Setting up Google Chrome Installation pre-reqs #####"
echo "##### Retreiving repository key and adding to apt #####"
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -

echo "##### Setting up apt repository for Google Chrome install #####"
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list

# Update the apt repository
echo "##### Updating apt repository #####"
apt-get update

# Install Google Chrome
echo "##### Installing Google Chrome #####"
apt-get -y install google-chrome-stable

# Install IntelliJ IDEA
echo "##### Installing IntelliJ IDEA Community Edition "#####"

echo "##### Fetching the latest version number #####"
# Fetch the most recent version
VERSION=$(wget "https://www.jetbrains.com/intellij-repository/releases" -qO- | grep -P -o -m 1 "(?<=https://www.jetbrains.com/intellij-repository/releases/com/jetbrains/intellij/idea/BUILD/)[^/]+(?=/)")
echo "##### IntelliJ Version Retrieval was Successful #####" 
# Prepend base URL for download
URL="https://download.jetbrains.com/idea/ideaIC-$VERSION.tar.gz"

# Truncate filename
FILE=$(basename ${URL})

# Set download directory
DEST=/tmp/$FILE

# Set directory name
DIR="/home/${USER}/idea"
    
# Download IntelliJ IDEA Community Edition
echo "##### Downloading idea-IC-$VERSION to $DEST... #####"
wget -cO ${DEST} ${URL} --read-timeout=5 --tries=0

# Unarchive download into specified directory
echo "##### Installing IntelliJ to $DIR #####"
if mkdir ${DIR}; then
    echo "##### Destination directory creation Successfull #####"
    tar -xzf ${DEST} -C ${DIR} --strip-components=1
else
    echo "##### Destination directory creation failed #####"
    exit 1
fi

# Cleanup installation
echo "##### Cleaning Up IntelliJ source file ${DEST} #####"
rm -f ${DEST}

# Change ownership of installation to ubuntu user
echo "##### Changing ownership of ${DIR} to ${USER} #####"
chown ${USER}:${USER} ${DIR}

# Install Visual Studio code
# Download pgp key
echo "##### Downloading VS Code pgp key #####"
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | apt-key add -

# Add VS Code to apt repository
echo "##### Updating apt repository for VS Code install #####"
add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"

# Update the apt repository
echo "##### Updating apt repository #####"
apt-get update

# Install VS Code
echo "##### Installing VS Code #####"
apt-get -y install code

# Docker installation
# Remove any previous Docker installs
echo "##### Removing previous Docker installations if any #####"
apt-get -y remove docker docker-engine docker.io containerd runc

# Update the apt repository
echo "##### updating apt repository #####"
apt-get update

# Install Docker pre-reqs
echo "##### Installing Docker pre-reqs #####"
apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Download pgp key
echo "##### Downloading Docker pgp key #####"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# Add Docker to apt repository
echo "##### Updating apt repository for Docker install #####"
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update the apt repository
echo "##### Updating apt repository #####"
apt-get update

# Install Docker
echo "##### Installing Docker #####"
apt-get -y install docker-ce docker-ce-cli containerd.io

# Add ubuntu to Docker group
echo "##### Adding ubuntu user to Docker group #####"
usermod -G docker ubuntu

# Enable docker at boot
echo "enabling docker startup on boot"
systemctl enable docker

#reboot the system
echo "##### Setup Complete, rebooting system #####"
reboot
