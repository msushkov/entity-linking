#! /bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export APP_HOME=`pwd`
export DEEPDIVE_HOME=`cd ../..; pwd`

# Machine Configuration
export MEMORY="64g"
export PARALLELISM=15

# SBT Options
export SBT_OPTS="-Xmx$MEMORY"

# Database Configuration
export PGPORT=5433
export PGHOST=madmax4
export DBNAME="deepdive_kbp"
export PGUSER=${PGUSER:-`whoami`}
export PGPASSWORD=${PGPASSWORD:-}

# Data files
export EL_RESULTS_FILE=$APP_HOME/evaluation/results/out.tsv
export EL_KBP_EVAL_QUERY=$APP_HOME/data/kbp-competition/el_2010_eval_queries.tsv
export EID_TO_FID_FILE=$APP_HOME/data/kbp-competition/eid_to_fid.csv
export AUX_TABLES=$APP_HOME/data/aux-tables.zip
export AUX_TABLES_DIR=$APP_HOME/data/aux-tables
export ENTITY_TABLES=$APP_HOME/data/entity-tables-other.zip
export ENTITY_TABLES_DIR=$APP_HOME/data/entity-tables-other
export ENTITY_TABLES_WIKI=$APP_HOME/data/entity-tables-wiki.zip
export ENTITY_TABLES_WIKI_DIR=$APP_HOME/data/entity-tables-wiki
export MENTION_TABLES=$APP_HOME/data/mention-tables.zip
export MENTION_TABLES_DIR=$APP_HOME/data/mention-tables
