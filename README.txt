Overview

To illustrate a concrete application of DeepDive, we provide an example baseline system for entity linking (EL), applied to the TAC KBP competition (http://www.nist.gov/tac/2013/KBP/EntityLinking/). The objective of the competition is to extract mentions of the type PERSON, ORGANIZATION, or LOCATION from a corpus of text documents, and to link these mentions to known Wikipedia entities. Participants in the competition are provided ~2 million news documents from which the evaluation queries will be pulled (an evaluation query is uniquely identified by the document id and mention text).

At a high level, the DeepDive system for EL includes the following components:
1. Identification of mentions of people, locations, and organizations in text
2. Identification of possible (entity, mention) pairs that could be linked (candidate links)
3. Feature extraction to predict which of the candidate links are likely to be correct (these features will be used in the inference rules)
4. Inference rules to make link predictions based on the features

Note: Please make sure to run env.sh before running any of the code below. From now on the example assumes the existence of certain environment variables.

Before we proceed we must load a few auxiliary tables, which will be useful in subsequent steps. Entity linking also assumes a reference knowledge base (KB), so we will load these tables as well.

0. Loading auxiliary and entity tables

Auxiliary tables

The following tables are located in data/aux-tables.zip:

- ambcode: ambiguous locations
- asquery: a given TACKBP evaluation query (includes the query id for evaluation and the mention id)
- usstate: all of the U.S. states
- wikidisamb_count: the number of links for a Wikipedia disambiguation page title

The asquery table is particularly useful for pruning the set of candidate mentions, since we only care to make predictions on the mentions that TAC KBP will evaluate us on.

The following code in setup_database.sh loads these into the database:

psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS ambcode CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS asquery CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS usstate CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS wikidisamb_count CASCADE;"

# if we already unzipped aux-tables.zip, no need to do it again
if [ -d "$AUX_TABLES_DIR" ]; then
  for file in `find $AUX_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
  done
else
  unzip $AUX_TABLES
  for file in `find $AUX_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
  done
fi

Entity tables

The KB is a set of Freebase entities with types. The following code in schema.sql defines the *canonical_entity* and *canonical_entity_type* tables:

DROP TABLE IF EXISTS canonical_entity CASCADE;
CREATE TABLE canonical_entity (
  id bigserial primary key,
  freebase_id text not null, -- Freebase id (e.g., /m/02mjmr)
  text text not null
);

  DROP TABLE IF EXISTS canonical_entity_type CASCADE;
  CREATE TABLE canonical_entity_type (
  id bigserial primary key,
  entity_id bigint references canonical_entity(id),
  raw_type text, -- /location/citytown
  type text -- LOCATION
);

We will populate the entity tables in the feature extraction step for convenience.

1. Identifying mentions in raw text

The next step is to find in text the mentions we care about. In other words, we want to identify all phrases that could link to PERSON, LOCATION, or ORGANIZATION entities.

The following code in schema.sql creates the mention table:

DROP TABLE IF EXISTS mention CASCADE;
CREATE TABLE mention (
  id bigserial primary key,
  mid text not null, 
  doc_id text not null, 
  sentence_id text not null, 
  token_offset_begin int,
  length int, -- tokens
  text text,
  type text,
  query_id text
);

Traditionally, the input to DeepDive would be a corpus of raw text files. The following parts of the example application walkthrough explain how to set up an NLP parser given a collection of text documents: http://deepdive.stanford.edu/doc/walkthrough.html#nlp_extractor and http://deepdive.stanford.edu/doc/walkthrough.html#people_extractor. However, this example aims to focus on the feature extraction and inference rules for entity linking, so it will be assumed that this preprocessing has been done. The file data/mention-tables.zip contains all of the necessary tables to continue this tutorial without performing text processing.
These tables are:

- mention: the mentions in text of people, locations, organizations
- mention_feature_type: the type (PERSON, etc) of the mention

The following code in setup_database.sh loads these tables into the database:
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS mention CASCADE;"
psql -p $PGPORT -h $PGHOST $DBNAME -c "DROP TABLE IF EXISTS mention_feature_type CASCADE;"

# if we already unzipped mention-tables.zip, no need to do it again
if [ -d "$MENTION_TABLES_DIR" ]; then
  for file in `find $MENTION_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
  done
else
  unzip $MENTION_TABLES
  for file in `find $MENTION_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
  done
fi

# construct the entity mention table
psql -p $PGPORT -h $PGHOST $DBNAME -c """
    INSERT INTO mention(doc_id, mid, sentence_id, text, query_id, is_correct) (
        SELECT trim(replace(replace(mention.docid3, 'DOC_', ''), '.sgm', '')) AS doc_id,
               trim(mention.mid1) AS mid,
               trim(mention.sentid2) AS sentence_id,
               trim(mention.word4) AS text,
               trim(asquery.qid2) AS query_id,
               TRUE AS is_correct
        FROM mention LEFT JOIN asquery ON
               asquery.mid1 = mention.mid1
    );"""
if [ "$?" != "0" ]; then echo "[80] FAILED!"; exit 1; fi


2. Identifying candidate links

To begin the process of inferring whether or not a particular (entity, mention) pair should be linked, we must first arrive at a list of candidate (entity, mention) pairs that will be used as input to the feature extraction step. The traditional DeepDive approach is to generate a large set of candidate (entity, mention) pairs, then to extract features from these pairs, and use these features in the inference rules to make decisions about candidates are the best.

In the current baseline system, the code that generates the candidate links is also the code that generates the features. This is because only candidates that satisfy at least one feature are useful; we do not want to consider candidates that do not.

3. Feature Extraction

Entity Features

Given that the entities we are working with come from Freebase, it is natural to consider certain Wikipedia features for a given entity. For example, the disambiguation page titles, the redirect page titles, and the anchor text of incoming links from other Wikipedia pages all are good ways of figuring out how a given entity is commonly written in text (e.g. Barack Hussein Obama as opposed to Barack Obama). Other useful signals are the search results that appear after a Bing query is made on the text of a particular mention. If one of these is the Wikipedia page of a given entity, it is likely that the entity and the mention are linked (very likely if the Wiki page is the top search result).

Since it is a routine task to obtain these features for the KB entities, this data is provided in the application’s data/ directory: the file entity-tables.zip contains all the necessary tables (as .sql files) to reconstruct the entities and their features. These tables are:

- entity: an entity in Freebase; the application creates canonical_entity from this table
- entity_feature_hasneed: the entities in this table all have titles consisting of text after a comma (this table only stores the entity id’s); these need deduplication
- entity_feature_popularity: the popularity of the given entity (80 is the highest)
- entity_feature_type: the Freebase type of the entity (e.g. /location/citytown)
- entity_feature_wikidisambiguation: the Wikipedia disambiguation page titles for a given entity
- entity_feature_wikiredirect: Wikipedia redirect page titles for a given entity
- entity_feature_bing_query: for a given Bing query, the entity corresponding to the Wikipedia page found in the results, as well as the rank of that page
- entity_feature_need_nodup: each of the entities here has a title consisting of text after a comma; these entities need deduplication (this table stores the entity id’s as well as the text after the comma)
- entity_feature_text_lc: the lowercase representation of the entity
- entity_feature_type_formatted: the formatted type (PERSON, LOCATION, ORGANIZATION)
- entity_feature_wikilink: the anchor text and frequency of internal Wikipedia page links to a given entity

The following code in setup_database.sh loads these tables into the database:

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
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
  done
else
  unzip $ENTITY_TABLES
  for file in `find $ENTITY_TABLES_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
  done
fi

# if we already unzipped entity-tables-wiki.zip, no need to do it again
if [ -d "$ENTITY_TABLES_WIKI_DIR" ]; then
  for file in `find $ENTITY_TABLES_WIKI_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
  done
else
  unzip $ENTITY_TABLES_WIKI
  for file in `find $ENTITY_TABLES_WIKI_DIR -name "*.sql"`; do 
    psql -p $PGPORT -h $PGHOST $DBNAME < $file
    if [ "$?" != "0" ]; then echo "[70] FAILED!"; exit 1; fi
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
if [ "$?" != "0" ]; then echo "[93] FAILED!"; exit 1; fi

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
if [ "$?" != "0" ]; then echo "[100] FAILED!"; exit 1; fi


Mention features

Features for mentions include the following functions of the mention text: lowercase, text abbreviation, the alphanumeric characters, the lowercase alphanumeric characters, the unigrams, and the number of words. For each such feature we define a table and an extractor.

Each of the tables is created in schema.sql using the statement like the one below. Refer to schema.sql for the complete list.

CREATE TABLE mention_feature_text_lc (
  id bigserial primary key,
  mention_id bigint not null references candidate_entity_mention(id),
  value text not null
);

Each of the extractors is defined in application.conf in a similar manner as below:

mention_text_lc {
      before: ${APP_HOME}"/udf/util/clear_table.sh mention_feature_text_lc"
      input: """
          SELECT id AS "mention.id",
                 text AS "mention.text"
            FROM mention
        """
      output_relation: "mention_feature_text_lc"
      udf: ${APP_HOME}"/udf/entity_linking/mention_features/mention_text_lc.py"
      parallelism: ${PARALLELISM}
    }

The extractor code, in ${APP_HOME}"/udf/entity_linking/mention_features/mention_text_lc.py", is below:

  #! /usr/bin/env python2.7

import fileinput
import json

for line in fileinput.input():
  row = json.loads(line.decode("latin-1").encode("utf-8"))
  
  mid = row['mention.id']
  text = row['mention.text']

  print json.dumps({
    "mention_id" : int(mid),
    "value" : text.lower()
  })

This extractor simply converts the mention text to lowercase. The other extractors for these features are very similar and can be found in udf/entity_linking/mention_features/.


(entity, mention) features

Now that we have extracted features for the entities and mentions separately, we need to figure out how they can link together. Each of these features will generate its own set of (entity, mention) pairs that satisfy the feature. The features are:

- All mentions link to the NIL entity
- If the mention text and entity text match exactly
- If the entity has a Wikipedia link with the same text as the mention
- If the entity has a Wikipedia redirect with the same text as the mention
- If the top Bing search result for the mention text is that entity’s Wikipedia page
- If the entity’s Wikipedia page appears as some (not necessarily the top) search result for the mention text

Each of the features will have its own table (the table schemas are identical). In schema.sql we have 6 statements of the form:

DROP TABLE IF EXISTS el_wiki_link CASCADE;
CREATE TABLE el_wiki_link (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references mention(id),
  is_correct boolean
);

For each of these, we also have an extractor in application.conf that will populate the corresponding table:

wiki_link {
      before: ${APP_HOME}"/udf/util/clear_table.sh el_wiki_link"
      input: """
          SELECT DISTINCT m.id AS "mention.id",
                 e.id AS "canonical_entity.id"
            FROM mention AS "m",
                 canonical_entity AS "e",
                 entity_feature_wikilink AS "w"
            WHERE e.freebase_id = trim(w.eid1) AND
                  m.text = trim(w.featurevalue3)
        """
      output_relation: "el_wiki_link"
      udf: ${APP_HOME}"/udf/entity_linking/rules/round_1/pass_through_eid_mid_istrue.py"
      parallelism: ${PARALLELISM}
    }

The extractor pass_through_eid_mid_istrue.py simply outputs the entity id and mention id that are passed to it:

  #! /usr/bin/env python2.7

import fileinput
import json

for line in fileinput.input():
  row = json.loads(line.decode("latin-1").encode("utf-8"))
  
  mid = row['mention.id']
  eid = row['canonical_entity.id']

  print json.dumps({
    "entity_id" : int(eid),
    "mention_id" : int(mid),
    "is_correct" : None
  })

The global set of candidates will be the union of the individual tables. The schema.sql definition for the global candidate link is:

CREATE TABLE el_candidate_link (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references candidate_entity_mention(id),
  is_correct boolean
);

Define an extractor in application.conf to generate this table:

el_round_1 {
      before: ${APP_HOME}"/udf/util/clear_table.sh el_candidate_link"
      input: """
          SELECT DISTINCT entity_id, mention_id
            FROM ( 
                (SELECT entity_id, mention_id FROM el_everything_nil)
              UNION
                (SELECT entity_id, mention_id FROM el_exact_str_match)
              UNION
                (SELECT entity_id, mention_id FROM el_wiki_link)
              UNION
                (SELECT entity_id, mention_id FROM el_wiki_redirect)
              UNION
                (SELECT entity_id, mention_id FROM el_top_bing_result)
              UNION
                (SELECT entity_id, mention_id FROM el_bing_result)
            ) AS t
        """
      output_relation: "el_candidate_link"
      udf: ${APP_HOME}"/udf/entity_linking/rules/round_1/combine_round_1_tables.py"
      parallelism: ${PARALLELISM}
      dependencies: ["everything_nil", "exact_str_match", "wiki_link", "wiki_redirect", "top_bing_result", "bing_result"]
    }

The extractor code is:

#! /usr/bin/env python2.7

import fileinput
import json

for line in fileinput.input():
  row = json.loads(line.decode("latin-1").encode("utf-8"))
  
  mid = row['mention_id']
  eid = row['entity_id']

  print json.dumps({
    "entity_id" : int(eid),
    "mention_id" : int(mid),
    "is_correct" : None
  })

This gives us the set of candidate links.


4. Inference Rules

Now that we have the candidate (entity, mention) links we can write inference rules to determine how strongly the system believes each link holds. A given link is represented by an indicator random variable; DeepDive represents these as the *is_correct* boolean column in the *el_candidate_link* table. *is_correct* will indicate whether or not the system thinks the given entity and mention should be linked (we call this is_correct because DeepDive will ultimately give us an expected value for each of these indicator variables, and this probability will correspond to the system’s confidence in the link).

We have the table el_candidate_link, which contains all of the candidate links for all our features. Each of the features also has its own candidate table, which is a subset of el_candidate_link. Essentially the hard work of generating the candidates for a given rule/feature was done when the given candidate table was populated. Now we must simply write inference rules on the variables we are trying to predict. For el_candidate_link we have 6 tables that indicate whether or not the corresponding subset of el_candidate_link’s variables is true. 

Example of rule:

rule_exact_str_match {
      input_query: """
          SELECT DISTINCT link.is_correct AS "el_candidate_link.is_correct",
                 link.id AS "el_candidate_link.id"
            FROM el_candidate_link link,
                 el_exact_str_match e
            WHERE link.entity_id = e.entity_id AND
                  link.mention_id = e.mention_id
        """
      function: "IsTrue(el_candidate_link.is_correct)"
      weight: 2
    }

Each of these rules is simply a join between el_candidate_link and the corresponding rule table, so the other 5 inference rules for this round are almost identical (with the exception of table e being different each time).

The inference rules are the last step before DeepDive can execute properly. It will construct a probabilistic graph out of all the boolean variables we want to predict and will run Gibbs sampling.

# Evaluation

After running run.sh, the system should output an F1-score on the TAC KBP 2010 evaluation set. The baseline system described in this example achieves a score of 0.75.

