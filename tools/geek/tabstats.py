#!/usr/bin/python
# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:               Thomas B. Preusser
#
# License:
# --------
# Copyright 2016-2016 Technische Universitaet Dresden - Germany
#                     Chair for VLSI-Design, Diagnostics and Architecture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

"""This tool computes the indentation histogram of a VHDL source file or source
tree. On this basis, it determines the corresponding optimal tab width setting
that minimizes the total number of space and tab characters needed to implement
the same indentation."""

VERBOSE  = 0
TABWIDTH = 2  # tab width to infer indentation as used in PoC

from sys import argv, stdout
import  os

# Add dictionary values that have the same key into the first argument
def merge(dicta, dictb):
	for key, val in dictb.items():
		dicta[key] = dicta.get(key, 0) + val

# Compute the indentation histogram for a source file or directory tree
def process(file):
	hist = {}
	if os.path.isdir(file):
		for root, dirs, files in os.walk(file):
			for f in files:
				if f.endswith('.vhdl'):
					merge(hist, process(os.path.join(root, f)))
	elif os.path.isfile(file):
		f = open(file, encoding='ISO-8859-1')
		for line in iter(f):
			indent = 0
			for c in line:
				if c == ' ':
				  indent = indent + 1
				elif c == "\t":
				  indent = TABWIDTH*(indent/TABWIDTH + 1)
				else:
					hist[indent] = hist.get(indent, 0) + 1
					break
		f.close()
	return  hist

# Print Histogram
def print_hist(title, hist):
	total = float(sum(hist.values()))

	print(title + ':')
	if VERBOSE:
		stdout.write('  Indent Prob\Tab')
		for j in range(1, 9):
			stdout.write("%6d "%j)
		print('')
		print('  ' + '-'*70)
	costs = [0]*9
	for i in sorted(hist):
		p = hist[i]/total
		if VERBOSE:
			stdout.write("%6d %7.3f%%  "%(i, 100*p))
		for j in range(1, 9):
			k = i/j + i%j
			if VERBOSE:
				stdout.write("%6d "%k)
			costs[j] = costs[j] + p*k
		if VERBOSE:
			print('')

	if VERBOSE:
		print('  ' + '-'*70)
	stdout.write("  Mean Costs     ")
	best = min(costs[1:9])
	for j in costs[1:9]:
		stdout.write("%6.3f%c"%(j, '*' if j == best else ' '))
	print('')

	if VERBOSE:
		print('  ' + '='*70)
	print('')

total_hist = {}
count = 0

# Process command-line arguments
for arg in argv[1:]:
	if arg == '-v':
		VERBOSE = 1
	elif arg.startswith('-t'):
		TABWIDTH=int(arg[2:])
	else:
		hist = process(arg)
		print_hist(arg, hist)
		merge(total_hist, hist)
		count = count + 1

if count > 1:
	print_hist('TOTAL', total_hist)
