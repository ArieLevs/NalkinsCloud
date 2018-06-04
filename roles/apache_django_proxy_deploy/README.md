Nalkinscloud Ansible Deployment
===============================

Optional vars:  
certificates_path  
Will indicate the location on your LOCAL machine which contains certificate, private key, and an optional fullchain cert.
The names of the files must be:

{{ domain_name }}.cer
{{ domain_name }}.fullchain.cer
{{ domain_name }}.key

for example, directory on my MacOS should contain in path
/Users/arielev/certificates  

nalkins.cloud.cer
nalkins.cloud.fullchain.cer
nalkins.cloud.key