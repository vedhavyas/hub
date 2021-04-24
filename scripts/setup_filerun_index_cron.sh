#!/bin/bash

docker exec filerun bash -c "
echo '/usr/local/bin/php /var/www/html/cron/process_search_index_queue.php' > /var/www/html/cron/process_search_index_queue.sh;
chmod 755 /var/www/html/cron/process_search_index_queue.sh;
echo '* * * * * root /var/www/html/cron/process_search_index_queue.sh > /proc/1/fd/1 2>/proc/1/fd/2
' > /etc/crontab;
/etc/init.d/cron start"

