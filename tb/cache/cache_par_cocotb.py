# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:				 		Martin Zabel
# 
# Cocotb Testbench:		Cache with parallel access to tags and data.
# 
# Description:
# ------------------------------------
#	Automated testbench for PoC.cache_par
#
# Supported configuration:
# * REPLACEMENT_POLICY = "LRU"
# * CACHE_LINES = ASSOCIATIVITY (full-associative cache)
# * USE_INITIAL_TAGS = false
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#											Chair for VLSI-Design, Diagnostics and Architecture
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#		http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

#import traceback
import random

import cocotb
from cocotb.decorators import coroutine
from cocotb.triggers import Timer, RisingEdge
from cocotb.monitors import BusMonitor
from cocotb.drivers import BusDriver
from cocotb.binary import BinaryValue
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.result import TestFailure, TestSuccess

from lru_dict import LeastRecentlyUsedDict

# ==============================================================================
class InputDriver(BusDriver):
	"""Drives inputs of DUT."""
	_signals = [ "Request", "ReadWrite", "Invalidate", "Replace", "Tag", "CacheLineIn" ]
	
	def __init__(self, dut):
		BusDriver.__init__(self, dut, None, dut.Clock)

class InputTransaction(object):
	"""Creates transaction to be send by InputDriver"""
	def __init__(self, tb, request=0, readWrite=0, invalidate=0, replace=0, tag=0, cacheLineIn=0):
		"tb must be an instance of the Testbench class"
		if (replace==1) and ((request==1) or (invalidate==1)):
			raise ValueError("InputTransaction.__init__ called with request=%d, invalidate=%d, replace=%d"
											 % request, invalidate, replace)
		
		self.Replace = BinaryValue(replace, 1)
		self.Request = BinaryValue(request, 1)
		self.ReadWrite = BinaryValue(readWrite, 1)
		self.Invalidate = BinaryValue(invalidate, 1)
		self.Tag = BinaryValue(tag, tb.tag_bits, False)
		self.CacheLineIn = BinaryValue(cacheLineIn, tb.data_bits, False)
		
# ==============================================================================
class InputMonitor(BusMonitor):
	"""Observes inputs of DUT."""
	_signals = [ "Request", "ReadWrite", "Invalidate", "Replace", "Tag", "CacheLineIn" ]
	
	def __init__(self, dut, callback=None, event=None):
		BusMonitor.__init__(self, dut, None, dut.Clock, dut.Reset, callback=callback, event=event)
		self.name = "in"
        
	@coroutine
	def _monitor_recv(self):
		clkedge = RisingEdge(self.clock)

		while True:
			# Capture signals at rising-edge of clock.
			yield clkedge
			vec = (self.bus.Request.value.integer,
						 self.bus.ReadWrite.value.integer,
						 self.bus.Invalidate.value.integer,
						 self.bus.Replace.value.integer,
						 self.bus.Tag.value.integer,
						 self.bus.CacheLineIn.value.integer)
			self._recv(vec)

# ==============================================================================
class OutputMonitor(BusMonitor):
	"""Observes outputs of DUT."""
	_signals = [ "CacheLineOut", "CacheHit", "CacheMiss", "OldTag", "OldCacheLine" ]

	def __init__(self, dut, callback=None, event=None):
		BusMonitor.__init__(self, dut, None, dut.Clock, dut.Reset, callback=callback, event=event)
		self.name = "out"
        
	@coroutine
	def _monitor_recv(self):
		clkedge = RisingEdge(self.clock)

		while True:
			# Capture signals at rising-edge of clock.
			yield clkedge
			
				
			vec = (self.bus.CacheLineOut.value.integer,
						 self.bus.CacheHit.value.integer,
						 self.bus.CacheMiss.value.integer,
						 self.bus.OldTag.value.integer,
						 self.bus.OldCacheLine.value.integer)
#			vec = tuple([getattr(self.bus,i).value.integer for i in self._signals])
			self._recv(vec)

# ==============================================================================
class Testbench(object):
	class Scoreboard(Scoreboard):
		def compare(self, got, exp, log, strict_type=True):
			"""Ignore received output if expected value is None"""
			for i, val in enumerate(exp):
				if val is not None:
					if val != got[i]:
						self.errors += 1
						log.error("Received transaction differed from expected output.")
						log.warning("Expected: %s.\nReceived: %s." % (exp, got))
						if self._imm:
							raise TestFailure("Received transaction differed from expected transaction.")

			
	def __init__(self, dut):
		self.dut = dut
		self.stopped = False
		self.tag_bits = dut.TAG_BITS.value
		self.data_bits = dut.DATA_BITS.value
		
		cache_lines = dut.CACHE_LINES.value      # total number of cache lines
		self.associativity = dut.ASSOCIATIVITY.value
		cache_sets = cache_lines / self.associativity # number of cache sets
		if cache_sets != 1:
			raise TestFailure("Unsupported configuration: CACHE_LINES=%d, ASSOCIATIVITY=%d" % (cache_lines, associativity))

		replacement_policy = dut.REPLACEMENT_POLICY.value
		if replacement_policy != "LRU":
			raise TestFailure("Unsupported configuration: REPLACEMENT_POLICY=%s" % replacement_policy)

		if dut.USE_INITIAL_TAGS.value != False:
			raise TestFailure("Unsupported configuration: USE_INITIAL_TAGS=true")

		# TODO: create LRU dictionary for each cache set
		self.lru = LeastRecentlyUsedDict(size_limit=self.associativity)

		init_val = (None, 0, 0, None, None)
		
		self.input_drv = InputDriver(dut)
		self.output_mon = OutputMonitor(dut)
		
		# Create a scoreboard on the outputs
		self.expected_output = [ init_val ]
		self.scoreboard = Testbench.Scoreboard(dut)
		self.scoreboard.add_interface(self.output_mon, self.expected_output)

		# Reconstruct the input transactions from the pins
		# and send them to our 'model'
		self.input_mon = InputMonitor(dut, callback=self.model)

	def model(self, transaction):
		'''Model the DUT based on the input transaction.'''
		request, readWrite, invalidate, replace, tag, cacheLineIn = transaction
		print "=== model called with stopped=%r, Request=%d, ReadWrite=%d, Invalidate=%d, Replace=%d, Tag=%d, CacheLineIn=%d" % (self.stopped, request, readWrite, invalidate, replace, tag, cacheLineIn)

		# expected outputs, None means ignore
		cacheLineOut, cacheHit, cacheMiss, oldTag, oldCacheLine = None, 0, 0, None, None
		if not self.stopped:
			if request == 1:
				if tag in self.lru:
					cacheHit = 1
					if readWrite == 1:
						self.lru[tag] = cacheLineIn
					else:
						cacheLineOut = self.lru[tag]

					if invalidate == 1:
						del self.lru[tag]
						
				else:
					cacheMiss = 1
					
			elif replace == 1:
				# check if a valid cache line will be replaced
				if len(self.lru) == self.associativity:
					oldTag, oldCacheLine = self.lru.iteritems().next()

				# actual replace
				self.lru[tag] = cacheLineIn

			print "=== model: lru = %s" % self.lru.items()
			self.expected_output.append( (cacheLineOut, cacheHit, cacheMiss, oldTag, oldCacheLine) )
			
	def stop(self):
		"""
		Stop generation of expected output transactions.
		One more clock cycle must be executed afterwards, so that, output of
		D-FF can be checked.
		"""
		self.stopped = True


# ==============================================================================
def random_input_gen(tb,n=2000):
	"""
	Generate random input data to be applied by InputDriver.
	Returns up to n instances of InputTransaction.
	tb must an instance of the Testbench class.
	"""
	tag_high  = 2**tb.tag_bits-1
	data_high = 2**tb.data_bits-1

	# it is forbidden to replace a cache line when the new tag is already within the cache
	# we cannot directly access the content of the LRU list in the testbench because this function is called asynchronously
	lru_tags = LeastRecentlyUsedDict(size_limit=tb.associativity)
	
	for i in range(n):
		command = random.randint(1,60)
		request, readWrite, invalidate, replace = 0, 0, 0, 0
		# 10% for each possible command
		if   command > 50: request = 1; readWrite = 0; invalidate = 0
		elif command > 40: request = 1; readWrite = 1; invalidate = 0
		elif command > 30: request = 1; readWrite = 0; invalidate = 1
		elif command > 20: request = 1; readWrite = 1; invalidate = 1
		elif command > 10: replace = 1

		# Upon request, check if tag is in LRU list.
		tag = random.randint(0,tag_high)
		while (replace == 1) and (tag in lru_tags):
			tag = random.randint(0,tag_high)

		# Update LRU list
		if request == 1:
			if tag in lru_tags:
				if invalidate == 1:
					del lru_tags[tag] # free cache line
				else:
					lru_tags[tag] = 1 # tag access
		elif replace == 1:
			lru_tags[tag] = 1 # allocate cache line

		#print "=== random_input_gen: request=%d, readWrite=%d, invalidate=%d, replace=%d, tag=%d" % (request, readWrite, invalidate, replace, tag)
		#print "=== random_input_gen: %s" % lru_tags.items()
		
		yield InputTransaction(tb, request, readWrite, invalidate, replace, tag, random.randint(0,data_high))

@cocotb.coroutine
def clock_gen(signal):
	while True:
		signal <= 0
		yield Timer(5000) # ps
		signal <= 1
		yield Timer(5000) # ps

@cocotb.coroutine
def run_test(dut):
	cocotb.fork(clock_gen(dut.Clock))
	tb = Testbench(dut)
	dut.Reset <= 0

	input_gen = random_input_gen(tb)
	
	# Issue first transaction immediately.
	yield tb.input_drv.send(input_gen.next(), False)

	# Issue next transactions.
	for t in input_gen:
		yield tb.input_drv.send(t)

	# Wait for rising-edge of clock to execute last transaction from above.
	# Apply idle command in following clock cycle, but stop generation of expected output data.
	# Finish clock cycle to capture the resulting output from the last transaction above.
	yield tb.input_drv.send(InputTransaction(tb))
	tb.stop()
	yield RisingEdge(dut.Clock)
	
	# Print result of scoreboard.
	raise tb.scoreboard.result

factory = TestFactory(run_test)
factory.generate_tests()
