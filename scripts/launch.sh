#!/bin/bash
./install.sh
/opt/armnas/fix_permissions.sh && /opt/armnas/fix_nginx.sh && /opt/armnas/fix_backend.sh
