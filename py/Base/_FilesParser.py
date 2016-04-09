# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:					Patrick Lehmann
# 
# Python Module:		TODO
# 
# Description:
# ------------------------------------
#		TODO:
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
#
from pyparsing import *
from pathlib import Path

class debug:
	_val = 0
	def inc(self):
		self._val += 1
	def dec(self):
		self._val -= 1
	def val(self):
		return self._val
		
dbg = debug()
		
class TSTAbstractNode:

	def parsePyParsingASTNode(self, ASTNode):
		print(("| " * dbg.val()) + "TSTAbstractNode.parsePyParsingASTNode: You MUST override this method!")

class TSTStatementListMixIn:
	def __init__(self):
		self._statements = []
	
	def parsePyParsingASTNode(self, ASTNode):
		print(("| " * dbg.val()) + "TSTStatementListMixIn.parsePyParsingASTNode: Parsing statement list...")
		for ASTItem in ASTNode:
			itemName = ASTItem.getName()
			if   (itemName == "ifthenelse"):	node = TSTNodeIfThenElseStatement()
			elif (itemName == "library"):			node = TSTNodeLibraryStatement()
			elif (itemName == "include"):			node = TSTNodeIncludeStatement()
			elif (itemName == "vhdl"):				node = TSTNodeVHDLStatement()
			else:
				print(("| " * dbg.val()) + "TSTStatementListMixIn.parsePyParsingASTNode: Unknown ASTItem name '{0}'.".format(itemName))
			dbg.inc()
			node.parsePyParsingASTNode(ASTItem)
			self.AddStatement(node)
			dbg.dec()

	def AddStatement(self, node):
		self._statements.append(node)
	
	def GetStatements(self):
		return self._statements
	
	def dump(self, indent):
		buffer = ""
		for stmt in self._statements:
			buffer += ("  " * indent) + stmt.dump(indent + 1) + "\n"
		return buffer

class TSTExpressionMixIn:
	def __init__(self):
		pass
	
	def parsePyParsingASTItem(self, ASTItem):
		itemName = ASTItem.getName()
		if (itemName == "notexpr"):
			node = TSTNodeNotExpression()
		elif (itemName == "andexpr"):
			node = TSTNodeAndExpression()
		elif (itemName == "orexpr"):
			node = TSTNodeOrExpression()
		elif (itemName == "equalexpr"):
			node = TSTNodeEqualExpression()
		elif (itemName == "notequalexpr"):
			node = TSTNodeNotEqualExpression()
		elif (itemName == "operand"):
			node = TSTNodeOperandExpression()
		else:
			print(("| " * dbg.val()) + "TSTExpressionMixIn.parsePyParsingExpressionNode: Unknown operator '{0}'.".format(itemName))
		node.parsePyParsingASTNode(ASTItem)
		return node
	
	def parsePyParsingASTNode(self, ASTNode):
		print(("| " * dbg.val()) + "type: {0}  narity: {1}".format(ASTNode.getName(), len(ASTNode)))
		if (len(ASTNode) <= 2):
			dbg.inc()
			ASTItem = ASTNode[0]
			node = self.parsePyParsingASTItem(ASTItem)
			self.AddLeftExpressionChild(node)
		
			if (len(ASTNode) == 2):
				ASTItem = ASTNode[1]
				node = self.parsePyParsingASTItem(ASTItem)
				self.AddRightExpressionChild(node)
				dbg.dec()
		else:
			print(("| " * dbg.val()) + "TSTExpressionMixIn.parsePyParsingExpressionNode: False operand count '{0}'.".format(len(ASTNode)))
		
class TSTExpressionRootMixIn(TSTExpressionMixIn):
	def __init__(self):
		super().__init__()
		self._expression =	None
	
	def parsePyParsingASTNode(self, ASTNode):
		NodeName = "expression"		#ASTNode.getName()
		if (NodeName == "expression"):
			print(("| " * dbg.val()) + "TSTExpressionRootMixIn.parsePyParsingASTNode: Parsing expression ...")
			print(dir(ASTAbstractNode))
			ASTItem = ASTNode[0]
			dbg.inc()
			node = self.parsePyParsingASTItem(ASTItem)
			self.AddExpressionRoot(node)
			dbg.dec()
		else:
			print(("| " * dbg.val()) + "TSTExpressionRootMixIn.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def AddExpressionRoot(self, node):
		self._expression = node
	
	def Evaluate(self):
		return True

class TSTUnaryExpressionMixIn:
	def __init__(self):
		self._child =	None
			
	def AddLeftExpressionChild(self, node):
		self._Child.append(node)
		
class TSTBinaryExpressionMixIn:
	def __init__(self):
		self._leftChild =		None
		self._rightChild =	None
			
	def AddLeftExpressionChild(self, node):
		self._leftChild.append(node)
	
	def AddRightExpressionChild(self, node):
		self._rightChild.append(node)
			
		
class TSTOperandMixIn:
	def __init__(self):
		self._operand =		None
	
	def parsePyParsingASTNode(self, ASTNode):
		print(("| " * dbg.val()) + "TSTOperandMixIn.parsePyParsingASTNode: Parsing operand ...")
		ASTName = ASTNode.getName()
		if   (ASTName == "identifier"):		node = TSTNodeIfThenElseStatement()
		elif (ASTName == "integer"):			node = TSTNodeLibraryStatement()
		else:
			print(("| " * dbg.val()) + "TSTOperandMixIn.parsePyParsingASTNode: Unknown ASTAbstractNode name '{0}'.".format(ASTName))
		dbg.inc()
		node.parsePyParsingASTNode(ASTNode[0])
		self.AddOperand(node)
		dbg.dec()

	def AddOperand(self, node):
		self._operand = node
	
	def dump(self):
		return self._operand.dump()

class TSTRoot(TSTAbstractNode, TSTStatementListMixIn):
	def __init__(self):
		TSTStatementListMixIn.__init__(self)
	
	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "body"):
			ASTItem = ASTNode[0]
			dbg.inc()
			TSTStatementListMixIn.parsePyParsingASTNode(self, ASTItem)
			dbg.dec()
		else:
			print(("| " * dbg.val()) + "TSTRoot.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def GetStatements(self):
		return TSTStatementListMixIn.GetStatements(self)
	
	def dump(self, indent):
		buffer = "Document root\n"
		buffer +=	TSTStatementListMixIn.dump(self, indent)
		return buffer
		
class TSTAbstractStatement(TSTAbstractNode):
	pass
		
class TSTNodeVHDLStatement(TSTAbstractStatement):
	def __init__(self):
		self._libraryName =	""
		self._file =				None

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "vhdl"):
			if (len(ASTNode) == 2):
				self._libraryName =	ASTNode[0][0]
				self._file =				Path(ASTNode[1][0])
				print(("| " * dbg.val()) + "VHDL statement found: {0} {1}".format(self._libraryName, str(self._file)))
			else:
				print(("| " * dbg.val()) + "TSTNodeVHDLStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print(("| " * dbg.val()) + "TSTNodeVHDLStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def GetFile(self):
		return self._file
	
	def GetLibraryName(self):
		return self._libraryName
	
	def dump(self, indent):
		return ("  " * indent) + "VHDL: lib='{0}'  file='{1}'".format(self._libraryName, str(self._file))
	
class TSTNodeIncludeStatement(TSTAbstractStatement):
	def __init__(self):
		self._file =			None

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "include"):
			if (len(ASTNode) == 1):
				self._file =			Path(ASTNode[0][0])
				print(("| " * dbg.val()) + "include statement found: {0}".format(str(self._file)))
			else:
				print(("| " * dbg.val()) + "TSTNodeIncludeStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print(("| " * dbg.val()) + "TSTNodeIncludeStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def GetFile(self):
		return self._file
	
	def dump(self, indent):
		return ("  " * indent) + "Include: file='{0}'".format(str(self._file))
		
class TSTNodeLibraryStatement(TSTAbstractStatement):
	def __init__(self):
		self._libraryName =	""
		self._directory =		None

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "library"):
			if (len(ASTNode) == 2):
				self._libraryName =		ASTNode[0][0]
				self._directory =			Path(ASTNode[1][0])
				print(("| " * dbg.val()) + "library statement found: {0} {1}".format(self._libraryName, str(self._directory)))
			else:
				print(("| " * dbg.val()) + "TSTNodeLibraryStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print(("| " * dbg.val()) + "TSTNodeLibraryStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def GetLibraryName(self):
		return self._libraryName
	
	def GetDirectory(self):
		return self._directory
	
	def dump(self, indent):
		return ("  " * indent) + "Library: lib='{0}'  dir='{1}'".format(self._libraryName, str(self._directory))

class TSTNodeIfThenElseStatement(TSTAbstractStatement):
	def __init__(self):
		self._ifClause =			None
		self._elseIfClauses =	[]
		self._elseClause =		None

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "ifthenelse"):
			print(("| " * dbg.val()) + "if-then-else statement found: ")
			for ASTItem in ASTNode:
				itemName = ASTItem.getName()
				if (itemName == "if"):
					dbg.inc()
					node = TSTNodeIfStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddIfClause(node)
					dbg.dec()
				elif (itemName == "elseif"):
					dbg.inc()
					node = TSTNodeElseIfStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddElseIfClause(node)
					dbg.dec()
				elif (itemName == "else"):
					dbg.inc()
					node = TSTNodeElseStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddElseClause(node)
					dbg.dec()
				else:
					print(("| " * dbg.val()) + "TSTNodeIfThenElseStatement.parsePyParsingASTNode: Unknown ASTItem name '{0}'.".format(itemName))
		else:
			print(("| " * dbg.val()) + "TSTNodeIfThenElseStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
		
	def AddIfClause(self, node):
		self._ifClause = node
		
	def AddElseIfClause(self, node):
		self._elseIfClauses.append(node)
		
	def AddElseClause(self, node):
		self._elseClause = node
	
	def dump(self, indent):
		buffer = self._ifClause.dump(indent)
		if (len(self._elseIfClauses) != 0):
			for clause in self._elseIfClauses:
				buffer += clause.dump(indent)
		if (self._elseClause is not None):
			buffer += self._elseClause.dump(indent)
		return buffer

class TSTAbstractIfThenElsePart(TSTAbstractNode, TSTStatementListMixIn):
	def __init__(self):
		TSTStatementListMixIn.__init__(self)
		
class TSTNodeIfStatement(TSTAbstractIfThenElsePart, TSTExpressionRootMixIn):
	def __init__(self):
		TSTAbstractIfThenElsePart.__init__(self)
		TSTExpressionRootMixIn.__init__(self)

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "if"):
			print(("| " * dbg.val()) + "if statement found: ")
			print(("| " * dbg.val()) + "sub AST: " + str(ASTNode[0]))
			
			exprRoot = ASTNode[0]
			stmtList = ASTNode[1]
			# if ((exprRoot.getName() == "expression") and (stmtList.getName() == "statement")):
			if ((True) and (stmtList.getName() == "statement")):
				dbg.inc()
				TSTExpressionRootMixIn.parsePyParsingASTNode(self, exprRoot)
				TSTStatementListMixIn.parsePyParsingASTNode(self, stmtList)
				dbg.dec()
			else:
				print(("| " * dbg.val()) + "TSTNodeIfStatement.parsePyParsingASTNode: False unknown subnodes.")
		else:
			print(("| " * dbg.val()) + "TSTNodeIfStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		buffer =	("  " * indent) + "if ({0})\n".format(TSTExpressionRootMixIn.dump(self))
		buffer += TSTStatementListMixIn.dump(indent + 1)
		return buffer
		
class TSTNodeElseIfStatement(TSTAbstractIfThenElsePart, TSTExpressionRootMixIn):
	def __init__(self):
		TSTAbstractIfThenElsePart.__init__(self)
		TSTExpressionRootMixIn.__init__(self)

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "elseif"):
			print(("| " * dbg.val()) + "elseif statement found: ")
			print(("| " * dbg.val()) + "sub AST: " + str(ASTNode[0]))
			
			exprRoot = ASTNode[0]
			stmtList = ASTNode[1]
			# if ((exprRoot.getName() == "expression") and (stmtList.getName() == "statement")):
			if ((True) and (stmtList.getName() == "statement")):
				dbg.inc()
				TSTExpressionRootMixIn.parsePyParsingASTNode(self, exprRoot)
				TSTStatementListMixIn.parsePyParsingASTNode(self, stmtList)
				dbg.dec()
			else:
				print(("| " * dbg.val()) + "TSTNodeElseIfStatement.parsePyParsingASTNode: False unknown subnodes.")
		else:
			print(("| " * dbg.val()) + "TSTNodeElseIfStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		buffer =	("  " * indent) + "elseif ({0})\n".format(self._expression.dump())
		buffer += TSTStatementListMixIn.dump(indent + 1)
		return buffer
		
class TSTNodeElseStatement(TSTAbstractIfThenElsePart):
	def __init__(self):
		TSTAbstractIfThenElsePart.__init__(self)

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "else"):
			print(("| " * dbg.val()) + "else statement found: ")
			
			stmtList = ASTNode[0]
			# if ((exprRoot.getName() == "expression") and (stmtList.getName() == "statement")):
			if (stmtList.getName() == "statement"):
				dbg.inc()
				TSTStatementListMixIn.parsePyParsingASTNode(self, stmtList)
				dbg.dec()
			else:
				print(("| " * dbg.val()) + "TSTNodeElseStatement.parsePyParsingASTNode: False unknown subnodes.")
		else:
			print(("| " * dbg.val()) + "TSTNodeElseStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		buffer =	("  " * indent) + "else\n"
		buffer += TSTStatementListMixIn.dump(indent + 1)
		return buffer
		
class TSTNodeExpression(TSTAbstractNode):
	def __init__(self):
		pass
	
class TSTNodeNotExpression(TSTNodeExpression, TSTUnaryExpressionMixIn):
	def __init__(self):
		super().__init__()
		TSTUnaryExpressionMixIn.__init__(self)
	
	def dump(self):
		return "(NOT {0})".format(self._child.dump())
	
class TSTNodeAndExpression(TSTNodeExpression, TSTExpressionMixIn):
	def __init__(self):
		TSTExpressionMixIn.__init__(self)
			
	def AddLeftExpressionChild(self, node):
		self._leftChild.append(node)
		
	def AddRightExpressionChild(self, node):
		self._rightChild.append(node)
	
	def dump(self):
		return "({0} AND {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class TSTNodeOrExpression(TSTNodeExpression, TSTExpressionMixIn):
	def __init__(self):
		TSTExpressionMixIn.__init__(self)
			
	def AddLeftExpressionChild(self, node):
		self._leftChild.append(node)
		
	def AddRightExpressionChild(self, node):
		self._rightChild.append(node)
		
	def dump(self):
		return "({0} OR {1})".format(self._leftChild.dump(), self._rightChild.dump())

class TSTNodeEqualalityExpression(TSTNodeExpression, TSTExpressionMixIn):
	def __init__(self):
		TSTExpressionMixIn.__init__(self)
		
class TSTNodeEqualExpression(TSTNodeEqualalityExpression):
	def dump(self):
		return "({0} = {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class TSTNodeNotEqualExpression(TSTNodeEqualalityExpression):
	def dump(self):
		return "({0} != {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class TSTNodeGreaterThanExpression(TSTNodeEqualalityExpression):
	def dump(self):
		return "({0} > {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class TSTNodeGreaterEqualThanExpression(TSTNodeEqualalityExpression):
	def dump(self):
		return "({0} >= {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class TSTNodeLessThanExpression(TSTNodeEqualalityExpression):
	def dump(self):
		return "({0} < {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class TSTNodeLessEqualThanExpression(TSTNodeEqualalityExpression):
	def dump(self):
		return "({0} <= {1})".format(self._leftChild.dump(), self._rightChild.dump())

class TSTNodeOperandExpression(TSTAbstractNode):
	def __init__(self):
		TSTOperandMixIn.__init__(self)
	
	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "operand"):
			print(("| " * dbg.val()) + "operand found: ")
			dbg.inc()
			ASTItem = ASTNode[0]
			TSTOperandMixIn.parsePyParsingASTNode(self, ASTItem)
			dbg.dec()
		else:
			print(("| " * dbg.val()) + "TSTNodeOperandExpression.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
		
class TSTNodeLiteral(TSTAbstractNode, TSTOperandMixIn):
	def __init__(self):
		TSTOperandMixIn.__init__(self)
	
class TSTNodeIntegerLiteral(TSTNodeLiteral):
	pass
	
class TSTNodeStringLiteral(TSTNodeLiteral):
	pass


def InfixNotation(baseExpr, opList):
	ret = Forward()
	lpar=Suppress('(')
	rpar=Suppress(')')
	lastExpr = baseExpr | ( lpar + ret + rpar )
	for i,operDef in enumerate(opList):
		opExpr,arity,rightLeftAssoc,name = (operDef)
		opExpr = Suppress(opExpr)
		thisExpr = Forward()#.setName("expr%d" % i)
		if rightLeftAssoc == opAssoc.LEFT:
			if arity == 1:
				matchExpr = FollowedBy(lastExpr + opExpr) + Group( lastExpr + OneOrMore( opExpr ) ).setResultsName(name)
			elif arity == 2:
				if opExpr is not None:
					matchExpr = FollowedBy(lastExpr + opExpr + lastExpr) + Group( lastExpr + OneOrMore( opExpr + lastExpr ) ).setResultsName(name)
				else:
					print("never reached")
					matchExpr = FollowedBy(lastExpr+lastExpr) + Group( lastExpr + OneOrMore(lastExpr) ).setResultsName(name)
			else:
				raise ValueError("operator must be unary (1) or binary (2)")
		elif rightLeftAssoc == opAssoc.RIGHT:
			if arity == 1:
				# try to avoid LR with this extra test
				if not isinstance(opExpr, Optional):
						opExpr = Optional(opExpr)
				matchExpr = FollowedBy(opExpr.expr + thisExpr) + Group( opExpr + thisExpr ).setResultsName(name)
			elif arity == 2:
				if opExpr is not None:
					matchExpr = FollowedBy(lastExpr + opExpr + thisExpr) + Group( lastExpr + OneOrMore( opExpr + thisExpr ) ).setResultsName(name)
				else:
					print("never reached")
					matchExpr = FollowedBy(lastExpr + thisExpr) + Group( lastExpr + OneOrMore( thisExpr ) ).setResultsName(name)
			else:
				raise ValueError("operator must be unary (1) or binary (2)")
		else:
			raise ValueError("operator must indicate right or left associativity")
		thisExpr <<= ( matchExpr | lastExpr )
		lastExpr = thisExpr
	ret <<= lastExpr
	return ret

class VHDLSourceFile:
	def __init__(self, file):
		if not isinstance(file, str):
			self._file = Path(file)
		else:
			self._file = file
			
	@property
	def File(self):
		return self._file
	
	def __str__(self):
		return "VHDL file: '{0}'".format(str(self._file))
	
	def __repr__(self):
		return self.__str__()
			
class VHDLLibraryReference:
	def __init__(self, name, path):
		self._name = name
		if isinstance(path, str):
			self._path = Path(path)
		else:
			self._path = path
	
	@property
	def Name(self):
		return self._name
		
	@property
	def Path(self):
		return self._path
	
	def __str__(self):
		return "VHDL library: {0} in '{1}'".format(self._name, str(self._path))
	
	def __repr__(self):
		return self.__str__()

class FilesParserMixIn:
	_parser =		None

	def __init__(self):
		self._rootDirectory =	None
		
		self.__AST =						None
		self.__TST =						None
		
		self._files =					[]
		self._includes =			[]
		self._libraries =			[]
		
	def _Parse(self):
		self._ReadContent()
		self._GenerateAbstractSyntaxTree()
		self._GenerateTypedSyntaxTree()
		
	def _GenerateAbstractSyntaxTree(self):
		self.__AST = self._parser.parseString(self._content, parseAll=True)
	
	def _GenerateTypedSyntaxTree(self):
		self.__TST = TSTRoot()
		self.__TST.parsePyParsingASTNode(self.__AST)
		
		# free space
		self.__AST = None
	
	def _SetVariables(self, variables):
		pass
	
	def _Resolve(self, TSTNode = None):
		print("Resolving {0}".format(str(self._file)))
		if (TSTNode is None):
			self._files =			[]
			self._includes =	[]
			self._libraries =	[]
			TSTNode = self.__TST
		
		for TSTItem in TSTNode.GetStatements():
			if isinstance(TSTItem, TSTNodeVHDLStatement):
				file =			self._rootDirectory / TSTItem.GetFile()
				vhdlSrcFile =	self._classVHDLSourceFile(file)
				self._files.append(vhdlSrcFile)
				
			elif isinstance(TSTItem, TSTNodeIncludeStatement):
				file =			self._rootDirectory / TSTItem.GetFile()
				incFile =		self._classFileListFile(file)
				self._fileSet.AddFile(incFile)
				incFile.Parse()
				
				self._includes.append(incFile)
				for vhdlFile in incFile.Files():
					self._files.append(vhdlFile)
				
				# load, parse, add
			elif isinstance(TSTItem, TSTNodeLibraryStatement):
				lib =					self._rootDirectory / TSTItem.GetDirectory()
				vhdlLibRef =	VHDLLibraryReference(TSTItem.GetLibraryName(), lib)
				self._libraries.append(vhdlLibRef)
				
			elif isinstance(TSTItem, TSTNodeIfThenElseStatement):
				if TSTItem._ifClause.Evaluate():
					print("  resolving if")
					self._Resolve(TSTItem._ifClause)
				else:
					for elsif in TSTItem._elseIfClauses:
						print("  resolving elseif")
						if elseif.Evaluate():
							self._Resolve(elseif)
							found = True
							break
					if (found == False):
						print("  resolving else")
						self._Resolve(TSTItem._elseClause)
	
	def Files(self):
		return self._files
		
	def Includes(self):
		return self._includes
		
	def Libraries(self):
		return self._libraries
	
	def __ConstructParser():
		INCLUDE =			Suppress("include")
		LIBRARY =			Suppress("library")
		VHDL =				Suppress("vhdl")

		IF =					Suppress("if")
		THEN =				Suppress("then")
		ELSIF =				Suppress("elsif")
		ELSE =				Suppress("else")
		ENDIF =				Suppress("end if")

		LPAR =				Suppress("(")
		RPAR =				Suppress(")")
		LBRACK =			Suppress("[")
		RBRACK =			Suppress("]")
		HASH =				Suppress("#")
						
		CONST_TRUE =	Suppress("true")
		CONST_FALSE =	Suppress("false")

		comment =			HASH + Optional(restOfLine)

		identifier =	Group(Word(alphas + "_", alphanums + "_")).setResultsName("identifier")
		integer =			Group(Regex(r"[+-]?\d+")).setResultsName("integer")
		string_ =			Group(dblQuotedString.addParseAction(removeQuotes)).setResultsName("string")

		# expressions
		expression =	Forward().setResultsName("expression")
		operand =			Group(identifier | integer | string_).setResultsName("operand")


		expression <<	Group(InfixNotation(operand, [
											(oneOf('= != < > <= >='), 2, opAssoc.LEFT,	"equalexpr"),
											(oneOf('not'),						1, opAssoc.RIGHT,	"notexpr"),
											(oneOf('and'),						2, opAssoc.LEFT,	"andexpr"),
											(oneOf('or'),							2, opAssoc.LEFT,	"orexpr"),
										]) + #			array access
										Optional(LBRACK + expression + RBRACK)
									)

		statement =		Forward().setResultsName("statement")
		incstmt =			(INCLUDE - string_).setResultsName("include")
		libstmt =			(LIBRARY - identifier + string_).setResultsName("library")
		vhdlstmt =		(VHDL - identifier + string_).setResultsName("vhdl")
		ifstmt =			Group(IF - LPAR + expression + RPAR + THEN + Group(ZeroOrMore(statement))).setResultsName("if")
		elsifstmt =		Group(ELSIF - LPAR + expression + RPAR + THEN + Group(ZeroOrMore(statement))).setResultsName("elseif")
		elsestmt =		Group(ELSE - Group(ZeroOrMore(statement))).setResultsName("else")
		ifelsestmt =	(ifstmt + Optional(elsifstmt) + Optional(elsestmt) + ENDIF).setResultsName("ifthenelse")
		statement <<	Group(ifelsestmt | incstmt | libstmt | vhdlstmt)

		# 
		body =	Group(ZeroOrMore(statement)).setResultsName("body")
		body.ignore(comment)
		return body
	_parser = __ConstructParser()
	
	def __str__(self):
		return "FILES file: '{0}'".format(str(self._file))
	
	def __repr__(self):
		return self.__str__()
