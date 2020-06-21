import codecs
import json
import sys

import dbFunc


# the db json file should be:
# * only dbMap, write contents unmodified:
#     {
#       'dbMap' : {...}
#     }
# * only dbEdit, load from current and apply edit:
#     {
#       'dbEdit' : {...}
#     }
# * dbMap and dbEdit, apply to dbMap:
#     {
#       'dbMap' : {...}
#       'dbEdit' : {...}
#     }
DB_JSON_FILE = sys.argv[1]
DB_FILE = sys.argv[2]
DB_COUNT_FILE = sys.argv[3]


# load config file
with codecs.open(DB_JSON_FILE, 'r', 'utf-8') as file:
    db = json.load(file)


# check load dbMap
if 'dbMap' not in db:
    dbFunc.dbLoad(db, DB_FILE, DB_COUNT_FILE)


# check apply dbEdit
if 'dbEdit' in db:
    dbFunc.dbEditApply(db, db['dbEdit'])


# finally write dbMap
dbFunc.dbSave(db, DB_FILE, DB_COUNT_FILE)

