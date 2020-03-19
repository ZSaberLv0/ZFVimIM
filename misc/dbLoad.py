import os
import codecs
import sys
import json

DB_JSON_FILE = sys.argv[1]
DB_FILE = sys.argv[2]
DB_COUNT_FILE = sys.argv[3]

ZFVimIM_KEY_HAS_WORD = '@@'


def ZFVimIM_dbMapItemDecode(dbMapItem):
    data = dbMapItem.split("\r")
    countList = []
    for count in data[1].split("\n"):
        countList.append(int(count))
    return {
        'wordList' : data[0].split("\n"),
        'countList' : countList,
    }
def ZFVimIM_dbMapItemEncode(dbMapItem):
    line = "\n".join(dbMapItem['wordList'])
    line += "\r"
    for count in dbMapItem['countList']:
        line += str(count)
        line += "\n"
    return line[0:-1]


def ZFVimIM_dbMapItemReorder(dbMapItem):
    tmp = []
    i = 0
    iEnd = len(dbMapItem['wordList'])
    while i < iEnd:
        tmp.append({
            'word' : dbMapItem['wordList'][i],
            'count' : dbMapItem['countList'][i],
        })
        i += 1
    tmp.sort(key = lambda e:e['count'], reverse = True)
    dbMapItem['wordList'] = []
    dbMapItem['countList'] = []
    for item in tmp:
        dbMapItem['wordList'].append(item['word'])
        dbMapItem['countList'].append(item['count'])

def dbKeyMapPrepare(dbKeyMap, key, i, iEnd):
    c = key[i]
    if c not in dbKeyMap:
        dbKeyMap[c] = {}
    if i == iEnd:
        dbKeyMap[c][ZFVimIM_KEY_HAS_WORD] = ''
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
        wordList.append(word.replace('_ZFVimIM_space_', ' '))
    if len(wordList) > 0:
        if key in db['dbMap']:
            dbMapItem = ZFVimIM_dbMapItemDecode(db['dbMap'][key])
            dbMapItem['wordList'].extend(wordList)
        else:
            dbMapItem = {
                'wordList' : wordList,
                'countList' : [],
            }
        while len(dbMapItem['countList']) < len(dbMapItem['wordList']):
            dbMapItem['countList'].append(0)
        ZFVimIM_dbMapItemReorder(dbMapItem)
        db['dbMap'][key] = ZFVimIM_dbMapItemEncode(dbMapItem)
        dbKeyMapPrepare(db['dbKeyMap'], key, 0, len(key) - 1)


if len(DB_COUNT_FILE) > 0 and os.access(DB_COUNT_FILE, os.F_OK) and os.access(DB_COUNT_FILE, os.R_OK):
    for line in codecs.open(DB_COUNT_FILE, 'r', 'utf-8'):
        line = line.splitlines()[0]
        split = line.split(' ', 1)
        key = split[0]
        countStrList = split[1].split(' ')
        if key not in db['dbMap']:
            continue
        dbMapItem = ZFVimIM_dbMapItemDecode(db['dbMap'][key])
        wordListLen = len(dbMapItem['wordList'])
        for i in range(len(countStrList)):
            if i >= wordListLen:
                break
            dbMapItem['countList'][i] += int(countStrList[i])
        ZFVimIM_dbMapItemReorder(dbMapItem)
        db['dbMap'][key] = ZFVimIM_dbMapItemEncode(dbMapItem)


with codecs.open(DB_JSON_FILE, 'w', 'utf-8') as file:
    json.dump(db, file)

