import os
import codecs
import sys
import json

DB_JSON_FILE = sys.argv[1]
DB_FILE = sys.argv[2]
DB_COUNT_FILE = sys.argv[3]


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


with codecs.open(DB_JSON_FILE, 'r', 'utf-8') as file:
    db = json.load(file)


lines = []
for key in db['dbMap']:
    line = key
    for word in ZFVimIM_dbMapItemDecode(db['dbMap'][key])['wordList']:
        line += ' ' + word.replace(' ', '\ ')
    line += '\n'
    lines.append(line)
lines.sort()
with codecs.open(DB_FILE, 'w', 'utf-8') as file:
    file.writelines(lines)


if len(DB_COUNT_FILE) > 0 and (not os.access(DB_COUNT_FILE, os.F_OK) or os.access(DB_COUNT_FILE, os.W_OK)):
    lines = []
    for key in db['dbMap']:
        line = key
        for count in ZFVimIM_dbMapItemDecode(db['dbMap'][key])['countList']:
            if count > 0:
                line += ' ' + str(count)
        if line != key:
            line += '\n'
            lines.append(line)
    lines.sort()
    with codecs.open(DB_COUNT_FILE, 'w', 'utf-8') as file:
        file.writelines(lines)

