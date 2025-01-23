#!/usr/bin/env python
""" 
Python script to download selected files from rda.ucar.edu.
After you save the file, don't forget to make it executable
i.e. - "chmod 755 <name_of_script>"
"""
import sys, os
from urllib.request import build_opener

opener = build_opener()

filelist = [
  'https://data.rda.ucar.edu/d084001/2017/20170427/gfs.0p25.2017042700.f000.grib2',
  'https://data.rda.ucar.edu/d084001/2017/20170427/gfs.0p25.2017042700.f003.grib2',
  'https://data.rda.ucar.edu/d084001/2017/20170427/gfs.0p25.2017042700.f006.grib2'
]

for file in filelist:
    ofile = os.path.basename(file)
    sys.stdout.write("downloading " + ofile + " ... ")
    sys.stdout.flush()
    infile = opener.open(file)
    outfile = open(ofile, "wb")
    outfile.write(infile.read())
    outfile.close()
    sys.stdout.write("done\n")
