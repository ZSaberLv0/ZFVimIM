import io
import json
import sys

import dbFunc


DB_FILE = sys.argv[1]
DB_COUNT_FILE = sys.argv[2]
DB_SAVE_CACHE_PATH = sys.argv[3]
CACHE_PATH = sys.argv[4]


dbEdit = []
with io.open(DB_SAVE_CACHE_PATH, 'r', encoding='utf-8') as file:
    for line in file:
        line = line.rstrip('\n')
        line = line.replace('\ ', '_ZFVimIM_space_')
        items = line.split(' ')
        if len(items) != 3:
            continue
        dbEdit.append({
            'action' : items[0].replace('_ZFVimIM_space_', ' '),
            'key' : items[1].replace('_ZFVimIM_space_', ' '),
            'word' : items[2].replace('_ZFVimIM_space_', ' '),
        })
pyMap = dbFunc.dbLoadPy(DB_FILE, DB_COUNT_FILE)
dbFunc.dbEditApplyPy(pyMap, dbEdit)
dbFunc.dbSavePy(pyMap, DB_FILE, DB_COUNT_FILE, CACHE_PATH)

