#!/bin/bash
#
# Script to bootstrap a Linux Desktop in AWS
# from AWS provided Ubuntu 18.04 AMI or RHEL 7.6 AMI
# Include this script as user data when launching
# an EC2 instance to turin instnace into desktop
# workstation.  Since cloud-init runs user data
# as root, no need for sudo.
#

# Determine OS Type
OSTYPE=$(head -1 /etc/os-release | awk -F"=" '{print $2}' | tr -d '"')

# Set OS and USER variables
if [ "${OSTYPE}" = "Ubuntu" ]; then
    OS="ubuntu"
    USER="ubuntu"
    echo "OS Type is ${OS}"
elif [ "${OSTYPE}" = "Red Hat Enterprise Linux Server" ]; then
    OS="rhel"
    USER="ec2-user"
    echo "OS Type is ${OS}"
else
    echo "OS Type not Recognized"
fi

# Update the apt repository
if [ "${OS}" = "ubuntu" ]; then
    echo "##### updating apt repository #####"
    apt-get update
fi

# Install desktop packages
if [ "${OS}" = "ubuntu" ]; then
    # Install Ubuntu Desktop Packages
    echo "##### Installing ubuntu-desktop packages #####"
    apt-get -y install ubuntu-desktop  
elif [ "${OS}" = "rhel" ]; then
    # Install RHEL Desktop Packages
    echo "##### Installing RHEL desktop packages #####"
    yum -y groupinstall "Server with GUI" 
else
    echo "Unsupported OS"
    exit 1
fi

# Install XRDP Packages
if [ "${OS}" = "ubuntu" ]; then
    # Install XRDP Packages for Ubuntu
    echo "##### Installing xrdp package for Ubuntu #####"
    apt-get -y install xrdp
elif [ "${OS}" = "rhel" ]; then
    # Install XRDP Packages for RHEL
    echo "##### Installing xrdp package for RHEL #####"
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    yum -y install xrdp
    # have to set color depth to 24 on rhel for IDEA to work
    echo "##### setting max color depth to 24 in xrdp #####"
    sed -i 's/max_bpp=32/max_bpp=24/' /etc/xrdp/xrdp.ini
else
    echo "Unsupported OS"
    exit 1
fi

# Run ubuntu specific tasks
if [ "${OS}" = "ubuntu" ]; then
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
        echo "##### Xwrapper.config does not exist, exiting #####"
        exit 1
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
    echo "##### Updating GNOME shell extenstion for dock #####"
    gnome-shell-extension-tool -e ubuntu-dock@ubuntu.com

    # Configure GNOME shell extenstions for app indicators
    echo "##### Updating GNOME shell extenstion for app indicators #####"
    gnome-shell-extension-tool -e ubuntu-appindicators@ubuntu.com
fi

# Update host firewalls to allow 3389
if [ "${OS}" = "ubuntu" ]; then
    # Allow 3389 through firewall
    echo "##### Modifying firewall to allow port 3389 #####"
    ufw allow 3389/tcp
elif [ "${OS}" = "rhel" ]; then
    # Allow 3389 through firewall
    echo "##### starting firewalld #####"
    systemctl start firewalld
    echo "##### Modifying firewall to allow port 3389 #####"
    firewall-cmd --permanent --add-port=3389/tcp 
    echo "##### reloading firewall policy #####"
    firewall-cmd --reload
    echo "##### setting selinux labels on xrdp binaries #####"
    chcon --type=bin_t /usr/sbin/xrdp
    chcon --type=bin_t /usr/sbin/xrdp-sesman
else
    echo "Unsupported OS"
    exit 1
fi

# Start XRDP on boot
echo "##### Enableing xrdp on system boot #####"
systemctl enable xrdp

# Install JDK 8
if [ "${OS}" = "ubuntu" ]; then
    # Install openjdk 8
    echo "##### Installing OpenJDK 8 #####"
    apt-get -y install openjdk-8-jdk
elif [ "${OS}" = "rhel" ]; then
    # Install openjdk 8
    echo "##### Installing OpenJDK 8 #####"
    yum -y install java-1.8.0-openjdk-devel
else
    echo "Unsupported OS"
    exit 1
fi

# Install python on ubunty only
if [ "${OS}" = "ubuntu" ]; then
    echo "##### Installing Python #####"
    apt-get -y install python
fi

# Install git on rhel only
if [ "${OS}" = "rhel" ]; then
    echo "##### Installing git #####"
    yum -y install git
fi

# Install Google Chrome
if [ "${OS}" = "ubuntu" ]; then 
    # then installing with apt-get
    echo "##### Setting up Google Chrome Installation pre-reqs #####"
    echo "##### Retreiving repository key and adding to apt #####"
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -

    echo "##### Setting up apt repository for Google Chrome install #####"
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list

    # Update the apt repository
    echo "##### updating apt repository #####"
    apt-get update

    # Install Google Chrome
    echo "##### Installing Google Chrome #####"
    apt-get -y install google-chrome-stable
elif [ "${OS}" = "rhel" ]; then
    echo "##### Downloading source packages #####"
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm -P /tmp
    wget http://rpmfind.net/linux/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/l/liberation-fonts-2.00.3-3.fc30.noarch.rpm -P /tmp
    wget http://rpmfind.net/linux/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/l/liberation-fonts-common-2.00.3-3.fc30.noarch.rpm -P /tmp
    wget http://rpmfind.net/linux/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/l/liberation-mono-fonts-2.00.3-3.fc30.noarch.rpm -P /tmp
    wget http://rpmfind.net/linux/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/l/liberation-sans-fonts-2.00.3-3.fc30.noarch.rpm -P /tmp
    wget http://rpmfind.net/linux/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/l/liberation-serif-fonts-2.00.3-3.fc30.noarch.rpm -P /tmp 

    echo "##### Installing pre-reqs #####"
    yum -y install redhat-lsb libXScrnSaver
    yum -y localinstall /tmp/liberation*

    echo "##### Installing Chrome #####"
    yum -y install /tmp/google-chrome-stable_current_x86_64.rpm
else
    echo "##### Unsupported OS #####"
fi

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
    

#Download IntelliJ IDEA Community Edition
echo "##### Downloading idea-IC-$VERSION to $DEST... #####"
wget -cO ${DEST} ${URL} --read-timeout=5 --tries=0

# unarchive download into specified directory
echo "##### Installing IntelliJ to $DIR #####"
if mkdir ${DIR}; then
    echo "##### Destination directory creation Successfull #####"
    tar -xzf ${DEST} -C ${DIR} --strip-components=1
else
    echo "##### Destination directory creation failed #####"
    exit 1
fi

#cleanup installation
echo "##### Cleaning Up IntelliJ source file ${DEST} #####"
rm -f ${DEST}

#change ownership of installation to ubuntu user
echo "##### Changing ownership of ${DIR} to ${USER} #####"
chown ${USER}:${USER} ${DIR}

# Docker installation
if [ "${OS}" = "ubuntu" ]; then
    # remove any previous Docker installs
    echo "##### Removing previous Docker installations if any #####"
    apt-get -y remove docker docker-engine docker.io containerd runc

    # Update the apt repository
    echo "##### updating apt repository #####"
    apt-get update

    # install Docker pre-reqs
    echo "##### Installing Docker pre-reqs #####"
    apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

    # Download pgp key
    echo "##### Downloading Docker pgp key #####"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

    # Add Docker to apt repository
    echo "##### Updating apt repository for Docker install #####"
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    # Update the apt repository
    echo "##### updating apt repository #####"
    apt-get update

    # Install Docker
    echo "##### Installing Docker #####"
    apt-get -y install docker-ce docker-ce-cli containerd.io

    # Enable Docker to start at system boot
    echo "##### Enabling Docker on system boot #####"
    systemctl enable docker

    # add ubuntu to Docker group
    echo "##### Adding ubuntu user to Docker group #####"
    usermod -G docker ubuntu
elif [ "${OS}" = "rhel" ]; then
    # add uinstall yum utils
    echo "##### installing yum utils #####"
    yum -y install yum-utils

    # add rhel server extras to yum config
    echo "##### adding rhel server extras to yum repo #####"
	yum-config-manager --enable rhui-REGION-rhel-server-extras

    #install docker
    echo "##### installing docker #####"
	yum -y install docker

    #enable docker at boot
    echo "enabling docker startup on boot"
    systemctl enable docker

    #create docker group
    echo "##### Creating Docker group"
    groupadd docker

    #add ec2-user to docker group
    echo "##### Adding ec2-user user to Docker group #####"
    usermod -G docker ec2-user
else
    echo "##### Unsupported OS #####"
fi

# Install Visual Studio code
if [ "${OS}" = "ubuntu" ]; then
    # Download pgp key
    echo "##### Downloading VS Code pgp key #####"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | apt-key add -

    # Add VS Code to apt repository
    echo "##### Updating apt repository for VS Code install #####"
    add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"

    # Update the apt repository
    echo "##### updating apt repository #####"
    apt-get update

    # Install VS Code
    echo "##### Installing VS Code #####"
    apt-get -y install code
elif [ "${OS}" = "rhel" ]; then
    #import the vs code package to rpm remo
    echo "##### Importing vs code rpm package to yum repo #####"
    rpm --import https://packages.microsoft.com/keys/microsoft.asc

    #update yum repo
    echo "##### updating yum repo #####"
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo
    
    #check update
    echo "##### running check update #####"
    yum check-update

    #install code
    echo "##### installing vs code #####"
    yum -y install code
else
    echo "##### Unsupported OS #####"
fi

# Set initial password for ${USER} user
echo "##### Setting initial password for ${USER} user #####"
usermod -p '$1$30437$nU28D8AX9wSj8rHE29V5n0' ${USER}

#reboot the system
echo "##### Setup Complete, rebooting system #####"
reboot