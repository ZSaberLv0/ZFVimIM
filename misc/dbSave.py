import io
import json
import sys

import dbFunc


DB_FILE = sys.argv[1]
DB_COUNT_FILE = sys.argv[2]
DB_SAVE_CACHE_PATH = sys.argv[3]


with io.open(DB_SAVE_CACHE_PATH, 'r', encoding='utf-8') as file:
    dbEdit = json.load(file)
pyMap = dbFunc.dbLoadPy(DB_FILE, DB_COUNT_FILE)
dbFunc.dbEditApplyPy(pyMap, dbEdit)
dbFunc.dbSavePy(pyMap, DB_FILE, DB_COUNT_FILE)

