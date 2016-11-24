
from enum      import Enum, unique		# EnumMeta
from time      import time
from colorama  import init, Fore

from Parser.VHDLParser import VHDL, EmptyLineBlock, IndentationBlock, CommentBlock
from lib.CodeDOM import CodeDOMObject
from lib.Functions import Init
from lib.Parser import MatchingParserResult, SpaceToken, CharacterToken, MismatchingParserResult, StringToken, NumberToken, ParserException

from lib.Parser     import Tokenizer

init(convert=True)

DEBUG =   True
DEBUG2 =  True

# print("{RED}{line}{NOCOLOR}".format(line="="*160, **Init.Foreground))

content = """\
-- one first comment line
-- a second comment line
	-- the third comment

library ieee;
-- comment four
use     ieee.std_logic_1164.all;  -- comment five
  use   ieee.numeric_std.all;

library  -- libcom1
  PoC    -- libcom2
  ;

entity test1 is
  -- comment six
end;

entity test2 is
  -- comment seven
	port (
		Clock    : in	 std_logic;
		Reset	   : in  std_logic;
		ClockDiv : out std_logic;
	);
end entity;

entity test3 is
	generic (
		BITS  : integer range 0 to 15;
		DEPTH : natural := 5
	);
	port (
		Clock    : in	 std_logic;
		Reset
		  : in  std_logic;
		ClockDiv : out
									 std_logic_vector(8-1 downto 0)
	);
end entity test3 ;

--		Clock    : in	 std_logic;   -- a line comment
--		Reset    : in  std_logic;		-- 2. line comment
--		ClockDiv : out              -- bad comment
--									 std_logic_vector(8-1 downto 0)

architecture rtl of test is
--	subtype T_SLV is std_logic_vector(7 downto 0);
--  type T_STATE is (ST_IDLE, ST_FINISH);
--  type T_Record is record
--		Member1 : STD_LOGIC;
--		Member2 : BOOLEAN
--	end record;
begin

--	process(Clock)
--	begin
--		if (Reset = '1') then
--			-- foo
--		end if;
--	end process;
end architecture;
""".replace("\r\n", "\n") # make it universal newline compatible

def StripAndFuse(generator):
	iterator =  iter(generator)
	lastBlock = next(iterator)
	yield lastBlock

	for block in iterator:
		if isinstance(block, (IndentationBlock, CommentBlock, EmptyLineBlock)):
			continue
		else:
			if (block.MultiPart == True):
				while True:
					nextBlock = next(iterator)
					if isinstance(nextBlock, (IndentationBlock, CommentBlock, EmptyLineBlock)):
						continue
					if (type(block) is not type(nextBlock)):
						raise ParserException("Error in multipart blocks. {0} <-> {1}".format(type(block), type(nextBlock)))

					nextBlock.StartToken.PreviousToken = block.EndToken
					block.EndToken = nextBlock.EndToken
					if (nextBlock.MultiPart == False):
						break

			block.PreviousBlock = lastBlock
			block.StartToken.PreviousToken = lastBlock.EndToken
			yield block
			lastBlock = block

# entry point
if __name__ == "__main__":
	alphaCharacters = Tokenizer.__ALPHA_CHARS__ + "_" + Tokenizer.__NUMBER_CHARS__
	wordTokenStream = Tokenizer.GetWordTokenizer(content, alphaCharacters=alphaCharacters)
	vhdlBlockStream = VHDL.TransformTokensToBlocks(wordTokenStream)

	try:
		for vhdlBlock in vhdlBlockStream:
			if isinstance(vhdlBlock, (EmptyLineBlock, IndentationBlock)):
				print("{DARK_GRAY}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
			elif isinstance(vhdlBlock, CommentBlock):
				print("{DARK_GREEN}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
			else:
				print("{YELLOW}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
	except ParserException as ex:
		print("ERROR: " + str(ex))
	except NotImplementedError as ex:
		print("NotImplementedError: " + str(ex))


	print("{RED}{line}{NOCOLOR}".format(line="="*160, **Init.Foreground))

	wordTokenStream = Tokenizer.GetWordTokenizer(content, alphaCharacters=alphaCharacters)
	vhdlBlockStream = VHDL.TransformTokensToBlocks(wordTokenStream)
	strippedBlockStream = StripAndFuse(vhdlBlockStream)

	try:
		for vhdlBlock in strippedBlockStream:
			if isinstance(vhdlBlock, (EmptyLineBlock, IndentationBlock)):
				print("{DARK_GRAY}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
			elif isinstance(vhdlBlock, CommentBlock):
				print("{DARK_GREEN}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
			else:
				print("{YELLOW}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
	except ParserException as ex:
		print("ERROR: " + str(ex))
	except NotImplementedError as ex:
		print("NotImplementedError: " + str(ex))
