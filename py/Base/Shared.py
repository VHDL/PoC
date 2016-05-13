# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:          Patrick Lehmann
#
# Python Class:     Base class for ***
#
# Description:
# ------------------------------------
#		TODO:
#		-
#		-
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#                     Chair for VLSI-Design, Diagnostics and Architecture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
#
# entry point
if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Class PoCCompiler")


# load dependencies
import re
import shutil
from pathlib            import Path
from os                 import chdir

from lib.Functions      import Init
from lib.Parser         import ParserException
from Base.Exceptions    import ExceptionBase
from Base.Logging       import ILogable
from Base.Project       import ToolChain, Tool, VHDLVersion, Environment, FileTypes
from Parser.RulesParser import CopyRuleMixIn, ReplaceRuleMixIn, DeleteRuleMixIn
from PoC.Solution       import VirtualProject, FileListFile, RulesFile


class Shared(ILogable):
	_TOOL_CHAIN =  ToolChain.Any
	_TOOL =        Tool.Any

	class __Directories__:
		Working = None
		PoCRoot = None

	def __init__(self, host, dryRun):
		if isinstance(host, ILogable):
			ILogable.__init__(self, host.Logger)
		else:
			ILogable.__init__(self, None)

		self._host =        host
		self._dryRun =      dryRun

		self._pocProject =  None
		self._directories = self.__Directories__()


	# class properties
	# ============================================================================
	@property
	def Host(self):         return self._host
	@property
	def PoCProject(self):   return self._pocProject
	@property
	def Directories(self):  return self._directories



