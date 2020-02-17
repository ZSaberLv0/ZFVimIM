import os
import codecs
import sys
import json

DB_JSON_FILE = sys.argv[1]
DB_FILE = sys.argv[2]
DB_COUNT_FILE = sys.argv[3]

ZFVimIM_dbHasWord = '@@'


def dbKeyMapPrepare(dbKeyMap, key, i, iEnd):
    c = key[i]
    if c not in dbKeyMap:
        dbKeyMap[c] = {}
    if i == iEnd:
        dbKeyMap[c][ZFVimIM_dbHasWord] = ''
    else:
        dbKeyMapPrepare(dbKeyMap[c], key, i + 1, iEnd)

db = {'dbMap' : {}, 'dbKeyMap' : {}}
for line in codecs.open(DB_FILE, 'r', 'utf-8'):
    line = line.splitlines()[0]
    split = line.split(' ', 1)
    key = split[0]
    wordListTmp = split[1].replace('\ ', '_ZFVimIM_space_').split(' ')
    wordList = []
    for word in wordListTmp:
        wordList.append({
            'word' : word.replace('_ZFVimIM_space_', ' '),
            'count' : 0,
        })
    db['dbMap'][key] = wordList
    dbKeyMapPrepare(db['dbKeyMap'], key, 0, len(key) - 1)


if len(DB_COUNT_FILE) > 0 and os.access(DB_COUNT_FILE, os.F_OK) and os.access(DB_COUNT_FILE, os.R_OK):
    for line in codecs.open(DB_COUNT_FILE, 'r', 'utf-8'):
        line = line.splitlines()[0]
        split = line.split(' ', 1)
        key = split[0]
        countList = split[1].split(' ')
        if key not in db['dbMap']:
            continue
        wordList = db['dbMap'][key]
        wordListLen = len(wordList)
        for i in range(len(countList)):
            if i >= wordListLen:
                break
            wordList[i]['count'] = int(countList[i])
        wordList.sort(key = lambda e:e['count'], reverse = True)


with codecs.open(DB_JSON_FILE, 'w', 'utf-8') as file:
    json.dump(db, file)

