
from pyparsing import *

INCLUDE =	Suppress("include")
LIBRARY =	Suppress("library")
VHDL =		Suppress("vhdl")

IF =			Suppress("if")
THEN =		Suppress("then")
ELSIF =		Suppress("elsif")
ELSE =		Suppress("else")
ENDIF =		Suppress("end if")

# AT =			Suppress("@")
LPAR =		Suppress("(")
RPAR =		Suppress(")")
LBRACK =	Suppress("[")
RBRACK =	Suppress("]")
HASH =		Suppress("#")
        
OP_EQ =		Suppress("=")
OP_NE =		Suppress("!=")
OP_GT =		Suppress(">")
OP_GE =		Suppress(">=")
OP_LT =		Suppress("<")
OP_LE =		Suppress("<=")

OP_NOT =	Suppress("not")
OP_AND =	Suppress("and")
OP_OR =		Suppress("or")

comment =			HASH + Optional(restOfLine)

identifier =	Word(alphas + "_", alphanums + "_").setResultsName("identifier")
integer =			Regex(r"[+-]?\d+").setResultsName("integer")
string_ =			dblQuotedString.setResultsName("string")

# expressions
# expression =	Forward().setResultsName("expression")
operand =			(identifier | integer | string_).setResultsName("operand")

operators =		[	(OP_EQ,		opAssoc.LEFT,		"equalexpr"),
								(OP_NE,		opAssoc.LEFT,		"notequalexpr"),
								# (OP_GT,		opAssoc.LEFT,		"greaterthanexpr"),
								# (OP_GE,		opAssoc.LEFT,		"greaterequalexpr"),
								# (OP_LT,		opAssoc.LEFT,		"lessthanexpr"),
								# (OP_LE,		opAssoc.LEFT,		"lessequalexpr"),
								# (OP_NOT,	opAssoc.RIGHT,	"notexpr"),
								(OP_AND,	opAssoc.LEFT,		"andexpr"),
								(OP_OR,		opAssoc.LEFT,		"orexpr")
							]

exprtree = Forward()
lastExpr = operand | ( LPAR + exprtree + RPAR )
for opExpr,rightLeftAssoc,name in operators:
	thisExpr = Forward()
	if (rightLeftAssoc == opAssoc.LEFT):
		matchExpr = FollowedBy(lastExpr + opExpr + lastExpr) + Group(lastExpr + OneOrMore(opExpr + lastExpr)).setResultsName(name)
	elif (rightLeftAssoc == opAssoc.RIGHT):
		matchExpr = FollowedBy(lastExpr + opExpr + thisExpr) + Group(lastExpr + OneOrMore(opExpr + thisExpr)).setResultsName(name)
	
	thisExpr <<= ( matchExpr | lastExpr )
	lastExpr = thisExpr
exprtree <<= lastExpr

expression =	exprtree.setResultsName("expression")
		
# def infixNotation( baseExpr, opList, lpar=Suppress('('), rpar=Suppress(')') ):
	# """Helper method for constructing grammars of expressions made up of
		 # operators working in a precedence hierarchy.  Operators may be unary or
		 # binary, left- or right-associative.  Parse actions can also be attached
		 # to operator expressions.

		 # Parameters:
			# - baseExpr - expression representing the most basic element for the nested
			# - opList - list of tuples, one for each operator precedence level in the
				# expression grammar; each tuple is of the form
				# (opExpr, numTerms, rightLeftAssoc, parseAction), where:
				 # - opExpr is the pyparsing expression for the operator;
						# may also be a string, which will be converted to a Literal;
						# if numTerms is 3, opExpr is a tuple of two expressions, for the
						# two operators separating the 3 terms
				 # - numTerms is the number of terms for this operator (must
						# be 1, 2, or 3)
				 # - rightLeftAssoc is the indicator whether the operator is
						# right or left associative, using the pyparsing-defined
						# constants C{opAssoc.RIGHT} and C{opAssoc.LEFT}.
				 # - parseAction is the parse action to be associated with
						# expressions matching this operator expression (the
						# parse action tuple member may be omitted)
			# - lpar - expression for matching left-parentheses (default=Suppress('('))
			# - rpar - expression for matching right-parentheses (default=Suppress(')'))
	# """
	# ret = Forward()
	# lastExpr = baseExpr | ( lpar + ret + rpar )
	# for i,operDef in enumerate(opList):
			# opExpr,arity,rightLeftAssoc,pa = (operDef + (None,))[:4]
			# if arity == 3:
					# if opExpr is None or len(opExpr) != 2:
							# raise ValueError("if numterms=3, opExpr must be a tuple or list of two expressions")
					# opExpr1, opExpr2 = opExpr
			# thisExpr = Forward()#.setName("expr%d" % i)
			# if rightLeftAssoc == opAssoc.LEFT:
					# if arity == 1:
							# matchExpr = FollowedBy(lastExpr + opExpr) + Group( lastExpr + OneOrMore( opExpr ) )
					# elif arity == 2:
							# if opExpr is not None:
									# matchExpr = FollowedBy(lastExpr + opExpr + lastExpr) + Group( lastExpr + OneOrMore( opExpr + lastExpr ) )
							# else:
									# matchExpr = FollowedBy(lastExpr+lastExpr) + Group( lastExpr + OneOrMore(lastExpr) )
					# elif arity == 3:
							# matchExpr = FollowedBy(lastExpr + opExpr1 + lastExpr + opExpr2 + lastExpr) + \
													# Group( lastExpr + opExpr1 + lastExpr + opExpr2 + lastExpr )
					# else:
							# raise ValueError("operator must be unary (1), binary (2), or ternary (3)")
			# elif rightLeftAssoc == opAssoc.RIGHT:
					# if arity == 1:
							# # try to avoid LR with this extra test
							# if not isinstance(opExpr, Optional):
									# opExpr = Optional(opExpr)
							# matchExpr = FollowedBy(opExpr.expr + thisExpr) + Group( opExpr + thisExpr )
					# elif arity == 2:
							# if opExpr is not None:
									# matchExpr = FollowedBy(lastExpr + opExpr + thisExpr) + Group( lastExpr + OneOrMore( opExpr + thisExpr ) )
							# else:
									# matchExpr = FollowedBy(lastExpr + thisExpr) + Group( lastExpr + OneOrMore( thisExpr ) )
					# elif arity == 3:
							# matchExpr = FollowedBy(lastExpr + opExpr1 + thisExpr + opExpr2 + thisExpr) + \
													# Group( lastExpr + opExpr1 + thisExpr + opExpr2 + thisExpr )
					# else:
							# raise ValueError("operator must be unary (1), binary (2), or ternary (3)")
			# else:
					# raise ValueError("operator must indicate right or left associativity")
			# if pa:
					# matchExpr.setParseAction( pa )
			# thisExpr <<= ( matchExpr | lastExpr )
			# lastExpr = thisExpr
	# ret <<= lastExpr
	# return ret

# expression <<	(operatorPrecedence(operand, [
									# (oneOf('= != < > <= >='), 2, opAssoc.LEFT),
									# (oneOf('not'),						1, opAssoc.RIGHT),
									# (oneOf('and'),						2, opAssoc.LEFT),
									# (oneOf('or'),							2, opAssoc.LEFT),
								# ]) + #			array access							or				function arguments
								# # Optional(LBRACK + expression + RBRACK | LPAR + Group(Optional(delimitedList(expression))) + RPAR)
								# Optional(LBRACK + expression + RBRACK)
							# )

statement =		Forward().setResultsName("statement")

incstmt =			(INCLUDE - string_).setResultsName("include")
libstmt =			(LIBRARY - identifier + string_).setResultsName("library")
vhdlstmt =		(VHDL - identifier + string_).setResultsName("vhdl")

ifstmt =			Group(IF - LPAR + expression + RPAR + THEN + Group(ZeroOrMore(statement))).setResultsName("if")
elsifstmt =		Group(ELSIF - LPAR + expression + RPAR + THEN + Group(ZeroOrMore(statement))).setResultsName("elseif")
elsestmt =		Group(ELSE - Group(ZeroOrMore(statement))).setResultsName("else")
ifelsestmt =	(ifstmt + Optional(elsifstmt) + Optional(elsestmt) + ENDIF).setResultsName("ifthenelse")

statement <<	Group(
								ifelsestmt |
								incstmt |
								libstmt |
								vhdlstmt
							)

# body = ZeroOrMore(vardecl) + ZeroOrMore(statement)
body =				ZeroOrMore(statement)	#.setResultsName("body")
body.ignore(comment)

debug_indent = 0

class ASTNode:
	pass

class ASTStatementList:
	def __init__(self):
		self._statements = []
	
	def parsePyParsingStatementList(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "statement"):
			print("ASTStatementList.parsePyParsingStatementList: Parsing statement list...")
			for ASTItem in ASTNode:
				itemName = ASTItem.getName()
				if (itemName == "vhdl"):
					node = ASTNodeVHDLStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddStatement(node)
				elif (itemName == "include"):
					node = ASTNodeIncludeStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddStatement(node)
				elif (itemName == "library"):
					node = ASTNodeLibraryStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddStatement(node)
				elif (itemName == "ifthenelse"):
					node = ASTNodeIfThenElseStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddStatement(node)
				else:
					print("ASTStatementList.parsePyParsingStatementList: Unknown ASTItem name '{0}'.".format(itemName))
		else:
			print("ASTStatementList.parsePyParsingStatementList: False ASTNode name '{0}'.".format(NodeName))

class ASTExpression:
	def __init__(self):
		self._leftSide =	None
		self._rightSide =	None
	
	def parsePyParsingExpressionTree(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "expression"):
			print("ASTExpression.parsePyParsingExpressionTree: Parsing expression tree...")
			print("LHS: " + str(ASTNode[0]))
			print("RHS: " + str(ASTNode[1]))
			pass
		else:
			print("ASTExpression.parsePyParsingExpressionTree: False ASTNode name '{0}'.".format(NodeName))
			
class ASTRoot(ASTNode, ASTStatementList):
	def __init__(self):
		ASTStatementList.__init__(self)
	
	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "statement"):	#body"):
			# debug_indent += 2
			self.parsePyParsingStatementList(ASTNode)
		else:
			print(" "*debug_indent + "ASTRoot.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
		
		# debug_indent -= 2
	
	def AddStatement(self, node):
		self._statements.append(node)
	
	def dump(self, indent):
		buffer = ""
		for stmt in self._statements:
			buffer += ("  " * indent) + stmt.dump(indent + 1) + "\n"
		
		return buffer
		
class ASTNodeStatement(ASTNode):
	pass
		
class ASTNodeVHDLStatement(ASTNodeStatement):
	def __init__(self):
		self._vhdlLibrary =	""
		self._fileName =			""

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "vhdl"):
			if (len(ASTNode) == 2):
				# keyWord =				ASTNode[0]
				self._vhdlLibrary =		ASTNode[0]
				self._fileName =			ASTNode[1]
				print(" "*debug_indent + "VHDL statement found: {0} {1}".format(self._vhdlLibrary, self._fileName))
			else:
				print(" "*debug_indent + "ASTNodeVHDLStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print(" "*debug_indent + "ASTNodeVHDLStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		return ("  " * indent) + "VHDL: lib='{0}'  file='{1}'".format(self._vhdlLibrary, self._fileName)
	
class ASTNodeIncludeStatement(ASTNodeStatement):
	def __init__(self):
		self._fileName =		""

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "include"):
			if (len(ASTNode) == 1):
				# keyWord =				ASTNode[0]
				self._fileName =			ASTNode[0]
				print(" "*debug_indent + "include statement found: {0}".format(self._fileName))
			else:
				print(" "*debug_indent + "ASTNodeIncludeStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print(" "*debug_indent + "ASTNodeIncludeStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		return ("  " * indent) + "Include: file='{0}'".format(self._fileName)
		
class ASTNodeLibraryStatement(ASTNodeStatement):
	def __init__(self):
		self._vhdlLibrary =	""
		self._directory =		""

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "library"):
			if (len(ASTNode) == 2):
				# keyWord =				ASTNode[0]
				self._vhdlLibrary =		ASTNode[0]
				self._directory =			ASTNode[1]
				print(" "*debug_indent + "library statement found: {0} {1}".format(self._vhdlLibrary, self._directory))
			else:
				print(" "*debug_indent + "ASTNodeLibraryStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print(" "*debug_indent + "ASTNodeLibraryStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		return ("  " * indent) + "Library: lib='{0}'  dir='{1}'".format(self._vhdlLibrary, self._directory)

class ASTNodeIfThenElseStatement(ASTNodeStatement):
	def __init__(self):
		self._ifClause =			None
		self._elseIfClauses =	[]
		self._elseClause =		None

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "ifthenelse"):
			print(" "*debug_indent + "if-then-else statement found: ")
			for ASTItem in ASTNode:
				itemName = ASTItem.getName()
				if (itemName == "if"):
					node = ASTNodeIfStatement()
					# debug_indent += 2
					node.parsePyParsingASTNode(ASTItem)
					self.AddIfClause(node)
				elif (itemName == "elseif"):
					node = ASTNodeElseIfStatement()
					node.parsePyParsingASTNode(ASTItem)
					# debug_indent += 2
					self.AddElseIfClause(node)
				elif (itemName == "else"):
					node = ASTNodeElseStatement()
					node.parsePyParsingASTNode(ASTItem)
					# debug_indent += 2
					self.AddElseClause(node)
				else:
					print(" "*debug_indent + "ASTNodeIfThenElseStatement.parsePyParsingASTNode: Unknown ASTItem name '{0}'.".format(itemName))
		else:
			print(" "*debug_indent + "ASTNodeIfThenElseStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
		
	def AddIfClause(self, node):
		self._ifClause = node
		
	def AddElseIfClause(self, node):
		self._elseIfClauses.append(node)
		
	def AddElseClause(self, node):
		self._elseClause = node
	
	def dump(self, indent):
		buffer =	("  " * indent) + "if ({0})\n".format("...")
		buffer += self._ifClause.dump(indent + 1)
		if (len(self._elseIfClauses) != 0):
			buffer += ("  " * indent) + "elseif ({0})\n".format("...")
			for clause in self._elseIfClauses:
				buffer += clause.dump(indent + 1)
		if (self._elseClause is not None):
			buffer += ("  " * indent) + "else\n"
			buffer += self._elseClause.dump(indent + 1)
		return buffer
		
class ASTNodeIfStatement(ASTNodeStatement, ASTExpression, ASTStatementList):
	def __init__(self):
		ASTExpression.__init__(self)
		ASTStatementList.__init__(self)

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "if"):
			print(" "*debug_indent + "if statement found: ")
			print(" "*debug_indent + "sub AST: " + str(ASTNode[0]))
			
			self.parsePyParsingExpressionTree(ASTNode[0])
			self.parsePyParsingStatementList(ASTNode[1])
		else:
			print(" "*debug_indent + "ASTNodeIfStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
		
	def AddStatement(self, node):
		self._statements.append(node)
	
	def dump(self, indent):
		buffer = ""
		for stmt in self._statements:
			buffer += ("  " * indent) + stmt.dump(indent) + "\n"
		
		return buffer
		
class ASTNodeElseIfStatement(ASTNodeStatement, ASTExpression, ASTStatementList):
	def __init__(self):
		ASTExpression.__init__(self)
		ASTStatementList.__init__(self)

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "elseif"):
			print(" "*debug_indent + "elseif statement found: ")
			print(" "*debug_indent + "sub AST: " + str(ASTNode[0]))
			
			self.parsePyParsingExpressionTree(ASTNode[0])
			self.parsePyParsingStatementList(ASTNode[1])
		else:
			print(" "*debug_indent + "ASTNodeElseIfStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
	
	def AddStatement(self, node):
		self._statements.append(node)
	
	def dump(self, indent):
		buffer = ""
		for stmt in self._statements:
			buffer += ("  " * indent) + stmt.dump(indent) + "\n"
		
		return buffer
		
class ASTNodeElseStatement(ASTNodeStatement, ASTStatementList):
	def __init__(self):
		ASTStatementList.__init__(self)

	def parsePyParsingASTNode(self, ASTNode):
		NodeName = ASTNode.getName()
		if (NodeName == "else"):
			print(" "*debug_indent + "else statement found: ")
			
			self.parsePyParsingStatementList(ASTNode[0])
		else:
			print(" "*debug_indent + "ASTNodeElseStatement.parsePyParsingASTNode: False ASTNode name '{0}'.".format(NodeName))
		
	def AddStatement(self, node):
		self._statements.append(node)
	
	def dump(self, indent):
		buffer = ""
		for stmt in self._statements:
			buffer += ("  " * indent) + stmt.dump(indent) + "\n"
		
		return buffer
		
class ASTNodeExpression(ASTNode, ASTExpression):
	def __init__(self):
		ASTExpression.__init__(self)
	
class ASTNodeAndExpression(ASTNodeExpression):
	pass
	
class ASTNodeOrExpression(ASTNodeExpression):
	pass

class ASTNodeEqualExpression(ASTNodeExpression):
	pass
	
class ASTNodeUnequalExpression(ASTNodeExpression):
	pass
	
class ASTNodeGreaterThanExpression(ASTNodeExpression):
	pass
	
class ASTNodeGreaterEqualThanExpression(ASTNodeExpression):
	pass
	
class ASTNodeLessThanExpression(ASTNodeExpression):
	pass
	
class ASTNodeLessEqualThanExpression(ASTNodeExpression):
	pass
	
class ASTNodeLiteral(ASTNode):
	pass
	
class ASTNodeIntegerLiteral(ASTNodeLiteral):
	pass
	
class ASTNodeStringLiteral(ASTNodeLiteral):
	pass
	


	
	
test = """# Copyright (c) Paebbels
library osvvm "../ghdl/osvvm"
library vunit "../ghdl/vunit"

# some conditional lines
if ((vendor = "Xilinx") and (board = "KC705") or (board = "VC707")) then
vhdl poc "file1.vhdl"
include "../xilinx.files"
end if

if (test = 5) then
	vhdl poc ".file2.vhdl"
	vhdl poc "../file3.vhdl"
else
	vhdl poc "../file4.vhdl"
end if

if (test8 != 5) then

elsif (test18 = 123123) then
	vhdl poc ".file2.vhdl"
	vhdl poc "../file3.vhdl"
	vhdl poc "../file4.vhdl"
else
				include "jksdcdj.files"
end if

include "../../tb/PoC.common.files"

vhdl poc		"../../src/arith/arith.pkg.vhdl"
vhdl poc		"../../src/arith/arith_prng.vhdl"

vhdl test		"../../tb/arith/arith_prng_tb.vhdl"
"""

AST = body.parseString(test, parseAll=True)

print("2-0    " + str(AST[2][0].getName()))
print("2-0-0  " + str(AST[2][0][0].getName()))
print("2-0-1  " + str(AST[2][0][1].getName()))
print("2-0-1-0" + str(AST[2][0][1][0].getName()))

import pprint

pprint.pprint(AST.asList())
print("=" * 80)

variables = {
	"vendor" :	"Xilinx",
	"board" :		"KC705",
	"fpga" :		"XC7K325T",
	"family" :	"Virtex",
	"Series" :	"7",
	"Env" :			"Simulation"
}

root = ASTRoot()
root.parsePyParsingASTNode(AST)
print("="*80)
print(root.dump(0))