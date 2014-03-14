#! /bin/bash


psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS result;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS best_result;"

psql -p $PGPORT -h $PGHOST $DBNAME -c """
	CREATE TABLE result AS (
		SELECT eval_query.query_id AS query_id,
		       e.freebase_id AS freebase_id,
		       link.expectation AS probability
	    FROM el_candidate_link_is_correct_inference AS link,
	         canonical_entity AS e,
	         entity_mention AS m,
	         el_kbp_eval_query AS eval_query
	    WHERE link.entity_id = e.id AND
	          link.mention_id = m.id AND
	          m.query_id = eval_query.query_id AND
	          trim(eval_query.doc_id) = trim(replace(replace(m.doc_id, 'DOC_', ''), '.sgm', '')) AND
	          trim(lower(eval_query.text)) = trim(lower(m.text))
);"""

psql -p $PGPORT -h $PGHOST $DBNAME -c """
	CREATE TABLE best_result AS (
		SELECT query_id, MAX(probability) AS probability
		FROM result
		GROUP BY query_id
);"""

psql -p $PGPORT -h $PGHOST $DBNAME -c """
	COPY (
		SELECT DISTINCT ON (el_kbp_eval_query.query_id) el_kbp_eval_query.query_id,
		       CASE WHEN eid_to_fid.entity_id IS NOT NULL THEN eid_to_fid.entity_id
		            ELSE 'NIL'
		       END
		FROM el_kbp_eval_query LEFT JOIN best_result ON
			best_result.query_id = el_kbp_eval_query.query_id
	      LEFT JOIN result ON
	        result.query_id = best_result.query_id AND result.probability = best_result.probability
	      LEFT JOIN eid_to_fid ON
	         eid_to_fid.freebase_id = result.freebase_id
	) TO '$EL_RESULTS_FILE' WITH DELIMITER AS E'\t'
;"""

psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS result;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS best_result;"

