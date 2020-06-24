import sys

import dbFunc


DB_FILE = sys.argv[1]


pyMap = dbFunc.dbLoadNormalizePy(DB_FILE)
dbFunc.dbSavePy(pyMap, DB_FILE, '')

