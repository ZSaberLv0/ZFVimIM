import io
import json
import sys

import dbFunc

DB_JSON_FILE = sys.argv[1]
DB_FILE = sys.argv[2]
DB_COUNT_FILE = sys.argv[3]

db = {}
dbFunc.dbLoad(db, DB_FILE, DB_COUNT_FILE)

with io.open(DB_JSON_FILE, 'w', encoding='utf-8') as file:
    json.dump(db, file)

