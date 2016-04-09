
from pyparsing import *

INCLUDE =			Suppress("include")
LIBRARY =			Suppress("library")
VHDL =				Suppress("vhdl")

IF =					Suppress("if")
THEN =				Suppress("then")
ELSIF =				Suppress("elsif")
ELSE =				Suppress("else")
ENDIF =				Suppress("end if")

# AT =					Suppress("@")
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
string_ =			Group(dblQuotedString).setResultsName("string")

# expressions
expression =	Forward().setResultsName("expression")
operand =			Group(identifier | integer | string_).setResultsName("operand")

def infixNotation2( baseExpr, opList):
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
					matchExpr = FollowedBy(lastExpr + thisExpr) + Group( lastExpr + OneOrMore( thisExpr ) ).setResultsName(name)
			else:
				raise ValueError("operator must be unary (1) or binary (2)")
		else:
			raise ValueError("operator must indicate right or left associativity")
		thisExpr <<= ( matchExpr | lastExpr )
		lastExpr = thisExpr
	ret <<= lastExpr
	return ret

expression <<	Group(infixNotation2(operand, [
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

# body = ZeroOrMore(vardecl) + ZeroOrMore(statement)
body =				Group(ZeroOrMore(statement)).setResultsName("body")
body.ignore(comment)

class ASTAbstractNode:

	def parsePyParsingASTNode(self, ASTNode):
		print("ASTAbstractNode.parsePyParsingASTNode: You MUST override this method!")

class ASTMixinStatementList:
	def __init__(self):
		self._statements = []
	
	def parsePyParsingASTNode(self, ASTAbstractNode):
		print("ASTMixinStatementList.parsePyParsingASTNode: Parsing statement list...")
		for ASTItem in ASTAbstractNode:
			itemName = ASTItem.getName()
			if   (itemName == "ifthenelse"):	node = ASTNodeIfThenElseStatement()
			elif (itemName == "library"):			node = ASTNodeLibraryStatement()
			elif (itemName == "include"):			node = ASTNodeIncludeStatement()
			elif (itemName == "vhdl"):				node = ASTNodeVHDLStatement()
			else:
				print("ASTMixinStatementList.parsePyParsingASTNode: Unknown ASTItem name '{0}'.".format(itemName))
			node.parsePyParsingASTNode(ASTItem)
			self.AddStatement(node)

	def AddStatement(self, node):
		self._statements.append(node)
	
	def dump(self, indent):
		buffer = ""
		for stmt in self._statements:
			buffer += ("  " * indent) + stmt.dump(indent + 1) + "\n"
		return buffer
			
class ASTMixinExpressionRoot:
	def __init__(self):
		self._expression =	None
	
	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = "expression"		#ASTAbstractNode.getName()
		if (NodeName == "expression"):
			print("ASTMixinExpressionRoot.parsePyParsingASTNode: Parsing expression ...")
			# print(dir(ASTAbstractNode))
			ASTItem = ASTAbstractNode[0]
			itemName = ASTItem.getName()
			print("type: {0}  narity: {1}".format(itemName, len(ASTItem)))
			
			if (itemName == "notexpr"):
				print("LHS: " + str(ASTItem[0]))
			
				pass
			elif (itemName == "andexpr"):
				print("LHS: " + str(ASTItem[0]))
				print("RHS: " + str(ASTItem[1]))
				pass
			elif (itemName == "orexpr"):
				node = ASTNodeOrExpression()
				node.parsePyParsingASTNode(ASTItem)
				self.AddExpressionRoot(node)
			else:
				print("ASTMixinExpressionRoot.parsePyParsingASTNode: Unknown operator '{0}'.".format(itemName))
		else:
			print("ASTMixinExpressionRoot.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
	
	def AddExpressionRoot(self, node):
		self._statements.append(node)
	
class ASTMixinUnaryExpression:
	def __init__(self):
		self._child =	None
			
	def AddLeftExpressionChild(self, node):
		self._Child.append(node)
		
class ASTMixinBinaryExpression:
	def __init__(self):
		self._leftChild =		None
		self._rightChild =	None
			
	def AddLeftExpressionChild(self, node):
		self._leftChild.append(node)
	
	def AddRightExpressionChild(self, node):
		self._rightChild.append(node)
			
class ASTMixinExpression:
	def __init__(self):
		pass
	
	def parsePyParsingASTNode(self, ASTAbstractNode):
		if (len(ASTAbstractNode) <= 2):
			ASTItem = ASTAbstractNode[0]
			itemName = ASTItem.getName()
			print("type: {0}  narity: {1}".format(itemName, len(ASTItem)))
			
			if (itemName == "notexpr"):
				node = ASTNodeNotExpression()
			elif (itemName == "andexpr"):
				node = ASTNodeAndExpression()
			elif (itemName == "orexpr"):
				node = ASTNodeOrExpression()
			elif (itemName == "equalexpr"):
				node = ASTNodeEqualExpression()
			elif (itemName == "notequalexpr"):
				node = ASTNodeNotEqualExpression()
			elif (itemName == "operand"):
				node = ASTNodeOperandExpression()
			else:
				print("ASTMixinExpression.parsePyParsingExpressionNode: Unknown operator '{0}'.".format(itemName))
			node.parsePyParsingASTNode(ASTItem)
			self.AddLeftExpressionChild(node)
		
			if (len(ASTAbstractNode) == 2):
				ASTItem = ASTAbstractNode[1]
				itemName = ASTItem.getName()
				print("type: {0}  narity: {1}".format(itemName, len(ASTItem)))
				
				if (itemName == "notexpr"):
					node = ASTNodeNotExpression()
				elif (itemName == "andexpr"):
					node = ASTNodeAndExpression()
				elif (itemName == "orexpr"):
					node = ASTNodeOrExpression()
				elif (itemName == "equalexpr"):
					node = ASTNodeEqualExpression()
				elif (itemName == "notequalexpr"):
					node = ASTNodeNotEqualExpression()
				elif (itemName == "operand"):
					node = ASTNodeOperandExpression()
			else:
				print("ASTMixinExpression.parsePyParsingExpressionNode: Unknown operator '{0}'.".format(itemName))
			node.parsePyParsingASTNode(ASTItem)
			self.AddRightExpressionChild(node)
		else:
			print("ASTMixinExpression.parsePyParsingExpressionNode: False operand count '{0}'.".format(len(ASTAbstractNode)))
		
class ASTMixinOperand:
	def __init__(self):
		self._operand =		None
	
	def parsePyParsingASTNode(self, ASTAbstractNode):
		print("ASTMixinOperand.parsePyParsingASTNode: Parsing operand ...")
		ASTName = ASTAbstractNode.getName()
		if   (ASTName == "identifier"):		node = ASTNodeIfThenElseStatement()
		elif (ASTName == "integer"):			node = ASTNodeLibraryStatement()
		else:
			print("ASTMixinOperand.parsePyParsingASTNode: Unknown ASTAbstractNode name '{0}'.".format(ASTName))
		node.parsePyParsingASTNode(ASTAbstractNode[0])
		self.AddOperand(node)

	def AddOperand(self, node):
		self._operand = node
	
	def dump(self):
		return self._operand.dump()

class ASTRoot(ASTAbstractNode, ASTMixinStatementList):
	def __init__(self):
		ASTMixinStatementList.__init__(self)
	
	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "body"):
			ASTItem = ASTAbstractNode[0]
			ASTMixinStatementList.parsePyParsingASTNode(self, ASTItem)
		else:
			print("ASTRoot.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		buffer = "Document root\n"
		buffer +=	ASTMixinStatementList.dump(self, indent)
		return buffer
		
class ASTAbstractStatement(ASTAbstractNode):
	pass
		
class ASTNodeVHDLStatement(ASTAbstractStatement):
	def __init__(self):
		self._vhdlLibrary =	""
		self._fileName =			""

	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "vhdl"):
			if (len(ASTAbstractNode) == 2):
				# keyWord =				ASTAbstractNode[0]
				self._vhdlLibrary =		ASTAbstractNode[0]
				self._fileName =			ASTAbstractNode[1]
				print("VHDL statement found: {0} {1}".format(self._vhdlLibrary, self._fileName))
			else:
				print("ASTNodeVHDLStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print("ASTNodeVHDLStatement.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		return ("  " * indent) + "VHDL: lib='{0}'  file='{1}'".format(self._vhdlLibrary, self._fileName)
	
class ASTNodeIncludeStatement(ASTAbstractStatement):
	def __init__(self):
		self._fileName =		""

	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "include"):
			if (len(ASTAbstractNode) == 1):
				# keyWord =				ASTAbstractNode[0]
				self._fileName =			ASTAbstractNode[0]
				print("include statement found: {0}".format(self._fileName))
			else:
				print("ASTNodeIncludeStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print("ASTNodeIncludeStatement.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		return ("  " * indent) + "Include: file='{0}'".format(self._fileName)
		
class ASTNodeLibraryStatement(ASTAbstractStatement):
	def __init__(self):
		self._vhdlLibrary =	""
		self._directory =		""

	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "library"):
			if (len(ASTAbstractNode) == 2):
				# keyWord =				ASTAbstractNode[0]
				self._vhdlLibrary =		ASTAbstractNode[0]
				self._directory =			ASTAbstractNode[1]
				print("library statement found: {0} {1}".format(self._vhdlLibrary, self._directory))
			else:
				print("ASTNodeLibraryStatement.parsePyParsingASTNode: False number of ASTItems.")
		else:
			print("ASTNodeLibraryStatement.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		return ("  " * indent) + "Library: lib='{0}'  dir='{1}'".format(self._vhdlLibrary, self._directory)

class ASTNodeIfThenElseStatement(ASTAbstractStatement):
	def __init__(self):
		self._ifClause =			None
		self._elseIfClauses =	[]
		self._elseClause =		None

	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "ifthenelse"):
			print("if-then-else statement found: ")
			for ASTItem in ASTAbstractNode:
				itemName = ASTItem.getName()
				if (itemName == "if"):
					node = ASTNodeIfStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddIfClause(node)
				elif (itemName == "elseif"):
					node = ASTNodeElseIfStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddElseIfClause(node)
				elif (itemName == "else"):
					node = ASTNodeElseStatement()
					node.parsePyParsingASTNode(ASTItem)
					self.AddElseClause(node)
				else:
					print("ASTNodeIfThenElseStatement.parsePyParsingASTNode: Unknown ASTItem name '{0}'.".format(itemName))
		else:
			print("ASTNodeIfThenElseStatement.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
		
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

class ASTAbstractIfThenElsePart(ASTAbstractNode, ASTMixinStatementList):
	def __init__(self):
		ASTMixinStatementList.__init__(self)
		
class ASTNodeIfStatement(ASTAbstractIfThenElsePart, ASTMixinExpressionRoot):
	def __init__(self):
		ASTAbstractIfThenElsePart.__init__(self)
		ASTMixinExpressionRoot.__init__(self)

	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "if"):
			print("if statement found: ")
			print("sub AST: " + str(ASTAbstractNode[0]))
			
			exprRoot = ASTAbstractNode[0]
			stmtList = ASTAbstractNode[1]
			# if ((exprRoot.getName() == "expression") and (stmtList.getName() == "statement")):
			if ((True) and (stmtList.getName() == "statement")):
				ASTMixinExpressionRoot.parsePyParsingASTNode(self, exprRoot)
				ASTMixinStatementList.parsePyParsingASTNode(self, stmtList)
			else:
				print("ASTNodeIfStatement.parsePyParsingASTNode: False unknown subnodes.")
		else:
			print("ASTNodeIfStatement.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		buffer =	("  " * indent) + "if ({0})\n".format(ASTMixinExpressionRoot.dump(self))
		buffer += ASTMixinStatementList.dump(indent + 1)
		return buffer
		
class ASTNodeElseIfStatement(ASTAbstractIfThenElsePart, ASTMixinExpressionRoot):
	def __init__(self):
		ASTAbstractIfThenElsePart.__init__(self)
		ASTMixinExpressionRoot.__init__(self)

	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "elseif"):
			print("elseif statement found: ")
			print("sub AST: " + str(ASTAbstractNode[0]))
			
			exprRoot = ASTAbstractNode[0]
			stmtList = ASTAbstractNode[1]
			# if ((exprRoot.getName() == "expression") and (stmtList.getName() == "statement")):
			if ((True) and (stmtList.getName() == "statement")):
				ASTMixinExpressionRoot.parsePyParsingASTNode(self, exprRoot)
				ASTMixinStatementList.parsePyParsingASTNode(self, stmtList)
			else:
				print("ASTNodeElseIfStatement.parsePyParsingASTNode: False unknown subnodes.")
		else:
			print("ASTNodeElseIfStatement.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		buffer =	("  " * indent) + "elseif ({0})\n".format(self._expression.dump())
		buffer += ASTMixinStatementList.dump(indent + 1)
		return buffer
		
class ASTNodeElseStatement(ASTAbstractIfThenElsePart):
	def __init__(self):
		ASTAbstractIfThenElsePart.__init__(self)

	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "else"):
			print("else statement found: ")
			
			stmtList = ASTAbstractNode[0]
			# if ((exprRoot.getName() == "expression") and (stmtList.getName() == "statement")):
			if (stmtList.getName() == "statement"):
				ASTMixinStatementList.parsePyParsingASTNode(self, stmtList)
			else:
				print("ASTNodeElseStatement.parsePyParsingASTNode: False unknown subnodes.")
		else:
			print("ASTNodeElseStatement.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
	
	def dump(self, indent):
		buffer =	("  " * indent) + "else\n"
		buffer += ASTMixinStatementList.dump(indent + 1)
		return buffer
		
class ASTNodeExpression(ASTAbstractNode):
	def __init__(self):
		pass
	
class ASTNodeNotExpression(ASTNodeExpression, ASTMixinUnaryExpression):
	def __init__(self):
		super().__init__()
		ASTMixinUnaryExpression.__init__(self)
	
	def dump(self):
		return "(NOT {0})".format(self._child.dump())
	
class ASTNodeAndExpression(ASTNodeExpression, ASTMixinExpression):
	def __init__(self):
		ASTMixinExpression.__init__(self)
			
	def AddLeftExpressionChild(self, node):
		self._leftChild.append(node)
		
	def AddRightExpressionChild(self, node):
		self._rightChild.append(node)
	
	def dump(self):
		return "({0} AND {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class ASTNodeOrExpression(ASTNodeExpression, ASTMixinExpression):
	def __init__(self):
		ASTMixinExpression.__init__(self)
			
	def AddLeftExpressionChild(self, node):
		self._leftChild.append(node)
		
	def AddRightExpressionChild(self, node):
		self._rightChild.append(node)
		
	def dump(self):
		return "({0} OR {1})".format(self._leftChild.dump(), self._rightChild.dump())

class ASTNodeEqualalityExpression(ASTNodeExpression, ASTMixinExpression):
	def __init__(self):
		ASTMixinExpression.__init__(self)
		
class ASTNodeEqualExpression(ASTNodeEqualalityExpression):
	def dump(self):
		return "({0} = {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class ASTNodeNotEqualExpression(ASTNodeEqualalityExpression):
	def dump(self):
		return "({0} != {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class ASTNodeGreaterThanExpression(ASTNodeEqualalityExpression):
	def dump(self):
		return "({0} > {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class ASTNodeGreaterEqualThanExpression(ASTNodeEqualalityExpression):
	def dump(self):
		return "({0} >= {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class ASTNodeLessThanExpression(ASTNodeEqualalityExpression):
	def dump(self):
		return "({0} < {1})".format(self._leftChild.dump(), self._rightChild.dump())
	
class ASTNodeLessEqualThanExpression(ASTNodeEqualalityExpression):
	def dump(self):
		return "({0} <= {1})".format(self._leftChild.dump(), self._rightChild.dump())

class ASTNodeOperandExpression(ASTAbstractNode):
	def __init__(self):
		ASTMixinOperand.__init__(self)
	
	def parsePyParsingASTNode(self, ASTAbstractNode):
		NodeName = ASTAbstractNode.getName()
		if (NodeName == "operand"):
			print("operand found: ")
			ASTItem = ASTAbstractNode[0]
			ASTMixinOperand.parsePyParsingASTNode(self, ASTItem)
		else:
			print("ASTNodeOperandExpression.parsePyParsingASTNode: False ASTAbstractNode name '{0}'.".format(NodeName))
		
class ASTNodeLiteral(ASTAbstractNode, ASTMixinOperand):
	def __init__(self):
		ASTMixinOperand.__init__(self)
	
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

print("=> " + AST[0][2][0][0][0][1])

# print("2-0    " + str(AST[2][0].getName()))
# print("2-0-0  " + str(AST[2][0][0].getName()))
# print("2-0-1  " + str(AST[2][0][1].getName()))
# print("2-0-1-0" + str(AST[2][0][1][0].getName()))

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
