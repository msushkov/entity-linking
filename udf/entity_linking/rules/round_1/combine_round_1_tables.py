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
