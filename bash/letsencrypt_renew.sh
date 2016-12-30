#!/bin/bash
# updates letsencrypt certs for $domain

echo -e "Apache needs to be down in order for the certification process to proceed. The following will run an emerge for the above ebuilds on the first loop, then should finish the following domains. Confirmation process on cert renewal, don't go away, Apache is down!\n"

service apache2 stop
for domain in domain1.com domain2.com; do
    /opt/letsencrypt/letsencrypt-auto certonly --debug --standalone -d $domain
done
service apache2 restart
