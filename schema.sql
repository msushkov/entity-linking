SET client_encoding = 'UTF8';

----
-- ENTITIES
----


-- entities in our knowledge base (freebase)
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

----
-- MENTIONS FOR ENTITIES
----

DROP TABLE IF EXISTS entity_mention CASCADE;
CREATE TABLE entity_mention (
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


----
-- MENTION FEATURES
----

-- text abbreviation (first letter of each word, but only if that letter is capitalized)
DROP TABLE IF EXISTS mention_feature_text_abbreviation CASCADE;
CREATE TABLE mention_feature_text_abbreviation (
  id bigserial primary key,
  mention_id bigint not null references entity_mention(id),
  value text not null
);

-- lowercase text
DROP TABLE IF EXISTS mention_feature_text_lc CASCADE;
CREATE TABLE mention_feature_text_lc (
  id bigserial primary key,
  mention_id bigint not null references entity_mention(id),
  value text not null
);

-- the alphanumeric text
DROP TABLE IF EXISTS mention_feature_text_alphanumeric CASCADE;
CREATE TABLE mention_feature_text_alphanumeric (
  id bigserial primary key,
  mention_id bigint not null references entity_mention(id),
  value text not null
);

-- the lowercase alphanumeric text
DROP TABLE IF EXISTS mention_feature_text_alphanumeric_lc CASCADE;
CREATE TABLE mention_feature_text_alphanumeric_lc (
  id bigserial primary key,
  mention_id bigint not null references entity_mention(id),
  value text not null
);

-- unigrams of the mention text
DROP TABLE IF EXISTS mention_feature_text_ngram1 CASCADE;
CREATE TABLE mention_feature_text_ngram1 (
  id bigserial primary key,
  mention_id bigint not null references entity_mention(id),
  value text not null
);

-- number of words in mention text
DROP TABLE IF EXISTS mention_feature_text_num_words CASCADE;
CREATE TABLE mention_feature_text_num_words (
  id bigserial primary key,
  mention_id bigint not null references entity_mention(id),
  value text not null
);

----
-- CANDIDATE LINKS
----

-- (entity, mention) pairs that could potentially be linked
DROP TABLE IF EXISTS el_candidate_link CASCADE;
CREATE TABLE el_candidate_link (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references entity_mention(id),
  is_correct boolean
);


----
-- ENTITY LINKING FEATURES
----

-- Rule 1: Everything is NIL by default
DROP TABLE IF EXISTS el_everything_nil CASCADE;
CREATE TABLE el_everything_nil (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references entity_mention(id),
  is_correct boolean
);

-- Rule 2: exact string matching
DROP TABLE IF EXISTS el_exact_str_match CASCADE;
CREATE TABLE el_exact_str_match (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references entity_mention(id),
  is_correct boolean
);

-- Rule 3: Wiki link
DROP TABLE IF EXISTS el_wiki_link CASCADE;
CREATE TABLE el_wiki_link (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references entity_mention(id),
  is_correct boolean
);

-- Rule 4: Wiki redirect
DROP TABLE IF EXISTS el_wiki_redirect CASCADE;
CREATE TABLE el_wiki_redirect (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references entity_mention(id),
  is_correct boolean
);

-- Rule 5: top Bing result
DROP TABLE IF EXISTS el_top_bing_result CASCADE;
CREATE TABLE el_top_bing_result (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references entity_mention(id),
  is_correct boolean
);

-- Rule 6: Bing result
DROP TABLE IF EXISTS el_bing_result CASCADE;
CREATE TABLE el_bing_result (
  id bigserial primary key,
  entity_id bigint not null references canonical_entity(id),
  mention_id bigint not null references entity_mention(id),
  is_correct boolean
);


----
-- TAC KBP-specific DATA
----

DROP TABLE IF EXISTS eid_to_fid CASCADE;
CREATE TABLE eid_to_fid (
  id bigserial primary key,
  entity_id text not null,
  freebase_id text not null
);

-- the evaluation queries for KBP
DROP TABLE IF EXISTS el_kbp_eval_query CASCADE;
CREATE TABLE el_kbp_eval_query (
  query_id text primary key,
  doc_id text not null,
  text text not null
);

