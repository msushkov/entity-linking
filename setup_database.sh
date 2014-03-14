#! /bin/bash

source "env.sh"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "-- Running in $SCRIPT_DIR --"

if [ "$DBNAME" == "" ]; then
  echo 'No database specified! Please set $DBNAME'
  exit 1
fi

dropdb $DBNAME
createdb $DBNAME
if [ "$?" != "0" ]; then echo "[10] FAILED!"; exit 1; fi

###
### Load the schema into the database
###

psql -p $PGPORT -h $PGHOST $DBNAME < schema.sql > /tmp/log
grep "ERROR:" /tmp/log
if [ "$?" == "0" ]; then echo "[20] FAILED!"; exit 1; fi
rm /tmp/log

###
### Load the auxiliary tables
###

psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS ambcode CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS asquery CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS usstate CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS wikidisamb_count CASCADE;"

# if we already unzipped aux-tables.zip, no need to do it again
if [ -d "$AUX_TABLES_DIR" ]; then
  for file in `find $AUX_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[30] FAILED!"; exit 1; fi
  done
else
  unzip $AUX_TABLES -d $AUX_TABLES_DIR
  for file in `find $AUX_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[40] FAILED!"; exit 1; fi
  done
fi


###
### Load the entity-related tables
###

psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_hasneed CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_popularity CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_type CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_wikidisambiguation CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_wikiredirect CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_bing_query CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_need_nodup CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_text_lc CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_type_formatted CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS entity_feature_wikilink CASCADE;"

# if we already unzipped entity-tables.zip, no need to do it again
if [ -d "$ENTITY_TABLES_DIR" ]; then
  for file in `find $ENTITY_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[50] FAILED!"; exit 1; fi
  done
else
  unzip $ENTITY_TABLES -d $ENTITY_TABLES_DIR
  for file in `find $ENTITY_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[60] FAILED!"; exit 1; fi
  done
fi

# if we already unzipped entity-tables-wiki.zip, no need to do it again
if [ -d "$ENTITY_TABLES_WIKI_DIR" ]; then
  for file in `find $ENTITY_TABLES_WIKI_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
  done
else
  unzip $ENTITY_TABLES_WIKI -d $ENTITY_TABLES_WIKI_DIR
  for file in `find $ENTITY_TABLES_WIKI_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[80] FAILED!"; exit 1; fi
  done
fi

# load the freebase entities
psql -p $PGPORT -h $PGHOST $DBNAME -c """
    INSERT INTO canonical_entity(freebase_id, text) (
        SELECT trim(eid1) AS freebase_id,
               trim(word2) AS text
        FROM entity
    );"""
if [ "$?" != "0" ]; then echo "[90] FAILED!"; exit 1; fi

# load the NIL entity (for TAC KBP)
psql -p $PGPORT -h $PGHOST $DBNAME -c """
    INSERT INTO canonical_entity(freebase_id, text) VALUES (
      'NIL0000', 'NIL0000'
    );"""
if [ "$?" != "0" ]; then echo "[100] FAILED!"; exit 1; fi

# load the entity types
psql -p $PGPORT -h $PGHOST $DBNAME -c """
    INSERT INTO canonical_entity_type(entity_id, raw_type, type) (
        SELECT canonical_entity.id AS entity_id,
               entity_feature_type.featurevalue2 AS raw_type,
               entity_feature_type_formatted.featurevalue2 AS type
        FROM entity LEFT JOIN entity_feature_type ON
               entity.eid1 = entity_feature_type.eid1
            LEFT JOIN entity_feature_type_formatted ON
               entity.eid1 = entity_feature_type_formatted.eid1
            LEFT JOIN canonical_entity ON
              trim(entity.eid1) = canonical_entity.freebase_id
    );"""
if [ "$?" != "0" ]; then echo "[110] FAILED!"; exit 1; fi


### Load the mention-related tables

psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS mention CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS mention_feature_type CASCADE;"

# if we already unzipped mention-tables.zip, no need to do it again
if [ -d "$MENTION_TABLES_DIR" ]; then
  for file in `find $MENTION_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[120] FAILED!"; exit 1; fi
  done
else
  unzip $MENTION_TABLES -d $MENTION_TABLES_DIR
  for file in `find $MENTION_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[130] FAILED!"; exit 1; fi
  done
fi

# construct the entity mention table
psql -p $PGPORT -h $PGHOST $DBNAME -c """
    INSERT INTO entity_mention(doc_id, mid, sentence_id, text, query_id) (
        SELECT trim(replace(replace(mention.docid3, 'DOC_', ''), '.sgm', '')) AS doc_id,
               trim(mention.mid1) AS mid,
               trim(mention.sentid2) AS sentence_id,
               trim(mention.word4) AS text,
               trim(asquery.qid2) AS query_id
        FROM mention LEFT JOIN asquery ON
               asquery.mid1 = mention.mid1
    );"""
if [ "$?" != "0" ]; then echo "[140] FAILED!"; exit 1; fi


### TAC KBP-specific stuff

# populate entity id -> freebase id mapping
psql -p $PGPORT -h $PGHOST $DBNAME -c "COPY eid_to_fid(entity_id, freebase_id) FROM STDIN CSV;" < $EID_TO_FID_FILE
if [ "$?" != "0" ]; then echo "[150] FAILED!"; exit 1; fi

# use this to get the query id for a given mention (identified by doc_id and text)
psql -p $PGPORT -h $PGHOST $DBNAME -c "COPY el_kbp_eval_query(query_id, doc_id, text) FROM STDIN DELIMITER E'\t';" < $EL_KBP_EVAL_QUERY
if [ "$?" != "0" ]; then echo "[160] FAILED!"; exit 1; fi
