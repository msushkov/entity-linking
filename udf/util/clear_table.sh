#! /usr/bin/env bash

psql -U $PGUSER -p $PGPORT -c "TRUNCATE $1 CASCADE;" $DBNAME
