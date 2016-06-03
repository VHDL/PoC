
from pathlib        import Path
from re             import compile as re_compile

def setup(app):
	pass
	
def main():
	sourceFile =    Path("../src/misc/sync/sync_Bits.vhdl")
	templateFile =  Path("Entity.template.rst")
	outputFile =    Path("PoC/misc/sync/sync_Bits.rst")
	print("Opening '{0!s}'...".format(sourceFile))

	entityStartRegExpStr = r"(?i)\s*entity\s+(?P<EntityName>\w+)\s+is"
	entityEndRegExpStr =   r"(?i)\s*end\s+entity(?:\s+\w)?;"

	entityStartRegExp = re_compile(entityStartRegExpStr)
	entityEndRegExp =   re_compile(entityEndRegExpStr)

	entityName =        ""
	entityStartLine =   0
	entityEndLine =     0
	enable =            None
	description =       ""

	with sourceFile.open('r') as vhdlFileHandle:
		lineNumber = 0
		for line in vhdlFileHandle:
			lineNumber += 1

			if ((line.startswith("-- =============================================================================")) and (enable is None)):
				enable = True
				continue
			elif (line.startswith("-- License:")):
				enable = False
			elif (entityStartLine == 0):
				entityStartMatch = entityStartRegExp.match(line)
				if (entityStartMatch is not None):
					entityName =      entityStartMatch.group("EntityName")
					entityStartLine = lineNumber
			else:
				entityEndMatch = entityEndRegExp.match(line)
				if (entityEndMatch is not None):
					entityEndLine = lineNumber
					break

			if enable:
				description += line[3:]

		else:
			raise Exception("No entity found.")

	print("Found an entity '{0}' at {1}..{2}.".format(entityName, entityStartLine, entityEndLine))

	with templateFile.open('r') as templateFileHandle:
		templateContent = templateFileHandle.read()

	outputContent = templateContent.format(
		EntityName=entityName,
		EntityNameUnderline="#"*len(entityName),
		EntityDescription=description,
		EntityFilePath=sourceFile.as_posix(),
		EntityDeclarationFromTo="{0}-{1}".format(entityStartLine, entityEndLine)
	)

	with outputFile.open('w') as restructuredTextHandle:
		restructuredTextHandle.write(outputContent)



if (__name__ == "__main__"):
	main()
