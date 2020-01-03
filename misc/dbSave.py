import os
import codecs
import sys
import json

DB_JSON_FILE = sys.argv[1]
DB_FILE = sys.argv[2]
DB_COUNT_FILE = sys.argv[3]


with codecs.open(DB_JSON_FILE, 'r', 'utf-8') as file:
    db = json.load(file)


lines = []
for key in db['dbMap']:
    line = key
    for word in db['dbMap'][key]:
        line += ' ' + word['word'].replace(' ', '\ ')
    line += '\n'
    lines.append(line)
lines.sort()
with codecs.open(DB_FILE, 'w', 'utf-8') as file:
    file.writelines(lines)


if len(DB_COUNT_FILE) > 0 and (not os.access(DB_COUNT_FILE, os.F_OK) or os.access(DB_COUNT_FILE, os.W_OK)):
    lines = []
    for key in db['dbMap']:
        line = key
        for word in db['dbMap'][key]:
            line += ' ' + str(word['count'])
        line += '\n'
        lines.append(line)
    lines.sort()
    with codecs.open(DB_COUNT_FILE, 'w', 'utf-8') as file:
        file.writelines(lines)

