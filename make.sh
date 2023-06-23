$HOME/pgsql/bin/pg_ctl -D $HOME/pgsql/data -l logfile stop
rm -r $HOME/pgsql
./configure --enable-depend --enable-cassert --enable-debug CFLAGS="-O0" --prefix=$HOME/pgsql --without-readline --without-zlib
make
make install
$HOME/pgsql/bin/initdb -D $HOME/pgsql/data --locale=C
$HOME/pgsql/bin/pg_ctl -D $HOME/pgsql/data -l logfile start
$HOME/pgsql/bin/psql -p 5432 postgres -c 'CREATE DATABASE similarity;'
$HOME/pgsql/bin/psql -p 5432 -d similarity -f $HOME/DatabasePJ/ similarity_data.sql
$HOME/pgsql/bin/psql similarity
