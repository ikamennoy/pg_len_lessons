./tpcc.lua cleanup --db-driver=pgsql --pgsql-db=postgres --pgsql-user=postgres  --pgsql-password="test123"
yc compute instance delete tu22p ; yc vpc subnet list|grep central|cut -d "|" -f 2 |xargs -n 1 yc vpc subnet delete; yc vpc network delete testnetb
