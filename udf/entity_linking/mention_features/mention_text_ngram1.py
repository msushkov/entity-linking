#! /usr/bin/env python2.7

import fileinput
import json

for line in fileinput.input():
	row = json.loads(line.decode("latin-1").encode("utf-8"))
	
	mid = row['mention.id']
	text = row['mention.text']

	# get all the unigrams
	for w in text.split():
		print json.dumps({
			"mention_id" : int(mid),
			"value" : w
		})
