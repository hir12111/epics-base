#!/bin/env python

import os, sys
from dlsxmlparserfunctions import *

# used for info fields: limits returned value to max
def limit(input,max):
	if int(input)<max:
		return input
	else:
		return max

# used for alarm summary: returns the name of the summary pv to be added
def summary(row,n,p,d,D,x=0):
	if int(D.lookup(row,n))>x:
		if x==0:
			return p+':'+n[1:]+':SUM'
		else:
			return p+':'+n[1:]+str(x)+':SUM'
	else:
		return p+':'+d[1:]+':SUM'

# write edm macro substitutions files
def gen_Db_info(table,D,filename):

	####################
	# hardcoded fields #
	####################
	template1 = "info-gui.template"
	template2 = "genericalarmsum.template"
	nflowlim = 6
	ntemplim = 24
	ncurrlim = 24

	##############
	# initialise #
	##############
	ioc = "BLxxI-XX-IOC-01"
	index = 0
	if D.ioc:
		ioc = D.ioc
	else:
		print "No IOC specified, defaulting to: "+ioc
	outfile = D.filef(filename,False)

	print "Wrote "+filename
	outfile.write("""#{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}
#######################################################
# This is an autogenerated substitution file.
# Please modify the source.
#######################################################
#{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}

file %s\n{
pattern { P,SHORTNAME,DESCRIPTION,NFLOW,NTEMP,NCURR,MTYPE,BL_SECTION,BL_ORDER}\n""" % (template1))
	for row in table:
		if D.rowtype(row)=="normal":
			out_row=D.insert_quotes(row)
			# write the GUI info fields
			outfile.write("#%s info fields\n\t{ %s, %s, %s, %s, %s, %s, %s, %s, %s }\n" % \
										( D.lookup(out_row, 'P'), D.lookup(out_row, 'P'),\
										  D.lookup(out_row, 'NAME'), \
										  D.lookup(out_row, 'DESCRIPTION'), \
										  limit(D.lookup(out_row, 'NFLOW'),nflowlim), \
										  limit(D.lookup(out_row, 'NTEMP'),ntemplim), \
										  limit(D.lookup(out_row, 'NCURR'),ncurrlim), \
										  D.lookup(out_row, 'MTYPE'), \
										  D.lookup(out_row, 'BL_SECTION'),str(index)))
		index += 1
	outfile.write("""}\n\nfile %s\n{
pattern { P, CALC, INPA, INPB, INPC, INPD, INPE, INPF, INPG, INPH, INPI, INPJ, INPK, INPL }\n""" % template2)
	for row in table:
		if D.rowtype(row)=="normal":
			out_row=D.insert_quotes(row)
			# Dn = dictionary of NTEMP, etc referenced by name
			Dn = {}
			# Nn = same dictionary referenced by value (used for working out the max value in the list)
			Nn = {}
			Total = 0
			# build Dn and Nn
			for s in ['NFLOW','NTEMP','NCURR','NMOTOR']:
				v = int(D.lookup(out_row,s))
				Nn[v] = s
				Dn[s] = v
				Total += v
			# if there are alarms to summarise, set d as the default (max value of NTEMP, etc)
			if not Total == 0:
				d = Nn[max(Nn)]
				p = D.lookup(out_row, 'P')
				outfile.write("#%s alarm summary\n\t{ %s, 1, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s }\n" % \
											( p, p+':SUM', \
											  summary(out_row, 'NFLOW',p,d,D), \
											  summary(out_row, 'NTEMP',p,d,D), \
											  summary(out_row, 'NTEMP',p,d,D,12), \
											  summary(out_row, 'NMOTOR',p,d,D), \
											  summary(out_row, 'NMOTOR',p,d,D,12), \
											  summary(out_row, 'NCURR',p,d,D), \
											  summary(out_row, 'NCURR',p,d,D,12), \
											  p+':'+d[1:]+':SUM', \
											  p+':'+d[1:]+':SUM', \
											  p+':'+d[1:]+':SUM', \
											  p+':'+d[1:]+':SUM', \
											  p+':'+d[1:]+':SUM'))
			if not Dn['NFLOW']==0:
			# summarise the flows alarms
				w = D.lookup(out_row,'W')
				d = D.lookup(out_row,'W1')
				outfile.write("\t{ %s, 1, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s }\n" % \
											( p+':FLOW:SUM', \
											  w+d+D.lookup(out_row,'ELO'), \
											  w+d+D.lookup(out_row,'ELOLO'), \
											  w+D.lookup(out_row,'W2',emptyval=d)+D.lookup(out_row,'ELO'), \
											  w+D.lookup(out_row,'W2',emptyval=d)+D.lookup(out_row,'ELOLO'), \
											  w+D.lookup(out_row,'W3',emptyval=d)+D.lookup(out_row,'ELO'), \
											  w+D.lookup(out_row,'W3',emptyval=d)+D.lookup(out_row,'ELOLO'), \
											  w+D.lookup(out_row,'W4',emptyval=d)+D.lookup(out_row,'ELO'), \
											  w+D.lookup(out_row,'W4',emptyval=d)+D.lookup(out_row,'ELOLO'), \
											  w+D.lookup(out_row,'W5',emptyval=d)+D.lookup(out_row,'ELO'), \
											  w+D.lookup(out_row,'W5',emptyval=d)+D.lookup(out_row,'ELOLO'), \
											  w+D.lookup(out_row,'W6',emptyval=d)+D.lookup(out_row,'ELO'), \
											  w+D.lookup(out_row,'W6',emptyval=d)+D.lookup(out_row,'ELOLO') ))
			# summarise the temp, current and motor alarms
			for s in ['NTEMP','NCURR','NMOTOR']:
				v = Dn[s]
				if not v == 0:
					d = D.lookup(out_row,s[1]+'1')
					outfile.write("\t{ %s, 1, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s }\n" % \
												( p+':'+s[1:]+':SUM', \
												  p+d+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'2',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'3',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'4',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'5',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'6',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'7',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'8',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'9',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'10',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'11',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'12',emptyval=d)+D.lookup(out_row,'E'+s[1:]) ))	
				if v > 12:
					d = D.lookup(out_row,s[1]+'13')
					outfile.write("\t{ %s, 1, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s }\n" % \
												( p+':'+s[1:]+'12:SUM', \
												  p+d+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'14',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'15',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'16',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'17',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'18',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'19',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'20',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'21',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'22',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'23',emptyval=d)+D.lookup(out_row,'E'+s[1:]), \
												  p+D.lookup(out_row,s[1]+'24',emptyval=d)+D.lookup(out_row,'E'+s[1:]) ))	

	outfile.write("}\n\n")
	D.closef()
