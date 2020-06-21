import io
import os
import re

ZFVimIM_KEY_HAS_WORD = '@@'


def dbMapItemDecode(dbMapItem):
    split = dbMapItem.split('\r')
    wordText = re.sub('^[\r\n]+|[\r\n]+$', '', split[0])
    wordList = wordText.split('\n')
    countText = re.sub('^[\r\n]+|[\r\n]+$', '', len(split) >= 2 and split[1] or '')
    countList = []
    for cnt in countText.split('\n'):
        if cnt != '':
            countList.append(int(cnt))
    while len(countList) < len(wordList):
        countList.append(0)
    return {
        'wordList' : wordList,
        'countList' : countList,
    }
def dbMapItemEncode(dbMapItem):
    line = '\n'.join(dbMapItem['wordList'])
    line += '\r'
    for cnt in dbMapItem['countList']:
        if cnt <= 0:
            break
        line += str(cnt)
        line += '\n'
    return line[0:-1]


def dbMapItemReorder(dbMapItem):
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


def _dbKeyMapAdd(dbMap, dbKeyMap, key):
    for i in range(len(key)):
        c = key[i]
        if c not in dbKeyMap:
            dbKeyMap[c] = {}
        dbKeyMap = dbKeyMap[c]
    dbKeyMap[ZFVimIM_KEY_HAS_WORD] = ''


def dbLoad(db, dbFile, dbCountFile):
    if 'dbMap' not in db:
        db['dbMap'] = {}
    if 'dbKeyMap' not in db:
        db['dbKeyMap'] = {}
    # load db
    for line in io.open(dbFile, 'r', encoding='utf-8'):
        if line.find('\ ') >= 0:
            wordListTmp = line.replace('\ ', '_ZFVimIM_space_').split(' ')
            if len(wordListTmp) > 0:
                key = wordListTmp[0]
                del wordListTmp[0]
            wordList = []
            for word in wordListTmp:
                wordList.append(word.replace('_ZFVimIM_space_', ' '))
        else:
            wordList = line.split(' ')
            if len(wordList) > 0:
                key = wordList[0]
                del wordList[0]
        if len(wordList) > 0:
            if key in db['dbMap']:
                dbMapItem = dbMapItemDecode(db['dbMap'][key])
                dbMapItem['wordList'].extend(wordList)
            else:
                dbMapItem = {
                    'wordList' : wordList,
                    'countList' : [],
                }
            for i in range(len(wordList)):
                dbMapItem['countList'].append(0)
            db['dbMap'][key] = dbMapItemEncode(dbMapItem)
            _dbKeyMapAdd(db['dbMap'], db['dbKeyMap'], key)
    # load word count
    if len(dbCountFile) > 0 and os.access(dbCountFile, os.F_OK) and os.access(dbCountFile, os.R_OK):
        for line in io.open(dbCountFile, 'r', encoding='utf-8'):
            countTextList = line.split(' ')
            if len(countTextList) <= 1:
                continue
            key = countTextList[0]
            if key not in db['dbMap']:
                continue
            dbMapItem = dbMapItemDecode(db['dbMap'][key])
            wordListLen = len(dbMapItem['wordList'])
            for i in range(len(countTextList) - 1):
                if i >= wordListLen:
                    break
                dbMapItem['countList'][i] = int(countTextList[i + 1])
            dbMapItemReorder(dbMapItem)
            db['dbMap'][key] = dbMapItemEncode(dbMapItem)
    # end of dbLoad


def dbSave(db, dbFile, dbCountFile):
    dbMap = db['dbMap']
    lines = []
    if len(dbCountFile) == 0 or not (not os.access(dbCountFile, os.F_OK) or os.access(dbCountFile, os.W_OK)):
        for key in sorted(db['dbMap'].keys()):
            line = key
            for word in dbMapItemDecode(db['dbMap'][key])['wordList']:
                line += ' '
                line += word.replace(' ', '\ ')
            line += '\n'
            lines.append(line)
        with io.open(dbFile, 'w', encoding='utf-8') as file:
            file.writelines(lines)
    else:
        countLines = []
        for key in sorted(db['dbMap'].keys()):
            line = key
            countLine = key
            dbMapItem = dbMapItemDecode(dbMap[key])
            for i in range(len(dbMapItem['wordList'])):
                line += ' '
                line += dbMapItem['wordList'][i].replace(' ', '\ ')
                if dbMapItem['countList'][i] > 0:
                    countLine += ' '
                    countLine += str(dbMapItem['countList'][i])
            line += '\n'
            lines.append(line)
            if countLine != key:
                countLine += '\n'
                countLines.append(countLine)
        with io.open(dbFile, 'w', encoding='utf-8') as file:
            file.writelines(lines)
        with io.open(dbCountFile, 'w', encoding='utf-8') as file:
            file.writelines(countLines)


# note, for python, we don't need to apply dbKeyMap
def dbEditApply(db, dbEdit):
    dbMap = db['dbMap']
    for e in dbEdit:
        key = e['key']
        word = e['word']
        if e['action'] == 'add':
            if key in dbMap:
                dbMapItem = dbMapItemDecode(dbMap[key])
                try:
                    index = dbMapItem['wordList'].index(word)
                except:
                    index = -1
                if index >= 0:
                    dbMapItem['countList'][index] += 1
                else:
                    dbMapItem['wordList'].append(word)
                    dbMapItem['countList'].append(1)
                dbMapItemReorder(dbMapItem)
                dbMap[key] = dbMapItemEncode(dbMapItem)
            else:
                dbMap[key] = dbMapItemEncode({
                    'wordList' : [word],
                    'countList' : [1],
                })
        elif e['action'] == 'remove':
            if key not in dbMap:
                continue
            dbMapItem = dbMapItemDecode(dbMap[key])
            try:
                index = dbMapItem['wordList'].index(word)
            except:
                index = -1
            if index < 0:
                continue
            del dbMapItem['wordList'][index]
            del dbMapItem['countList'][index]
            if len(dbMapItem['wordList']) == 0:
                del dbMap[key]
            else:
                dbMap[key] = dbMapItemEncode(dbMapItem)
        elif e['action'] == 'reorder':
            if key not in dbMap:
                continue
            dbMapItem = dbMapItemDecode(dbMap[key])
            try:
                index = dbMapItem['wordList'].index(word)
            except:
                index = -1
            if index < 0:
                continue
            dbMapItem['countList'][index] = 0
            sum = 0
            for cnt in dbMapItem['countList']:
                sum += cnt
            dbMapItem['countList'][index] = int(dbMapItem['countList'][index] / 2)
            dbMapItemReorder(dbMapItem)
            dbMap[key] = dbMapItemEncode(dbMapItem)
    # end of dbEditApply

