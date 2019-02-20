# linux-desktop
 
Include this script as user data when launching
an EC2 instance to turn instnace into desktop
workstation accessible via RDP.  Since cloud-init runs user data
as root, no need for sudo.
 
Once script runs, DO NOT log into the instance.
Create an AMI from the instance then boot a new instance
from the AMI.  

When booting an instance from the AMI, an initial password
needs to be set for either the ubuntu or ec2-user user depending
on which distro you used.

Generate a password hash on any linux or MacOS system:
openssl passwd -1 -salt $RANDOM PASSWORD
replace PASSWORD with the desired password.  This will create a hash

When creating the new instance, include the below as user data
usermod -p 'OPENSSL OUTPUT' ubuntu|ec2-user (pick one)

Once the instance boots, use RDP client to connect

