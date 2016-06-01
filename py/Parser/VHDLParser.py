
class VHDLKeywords:
	If =            CommonKeywords.If
	Then =          CommonKeywords.Then
	ElsIf =          CommonKeywords.ElsIf
	Else =          CommonKeywords.Else
	End =            CommonKeywords.End

	Package =        Keyword("package")
	Body =          Keyword("body")
	Entity =        Keyword("entity")
	Generic =        Keyword("generic")
	Port =          Keyword("port")
	Map =            Keyword("map")
	Architecture =  Keyword("architecture")
	Begin =          CommonKeywords.Begin

class VHDLRules:
	EndIf =              Sequence(VHDLKeywords.End, Rules.WhiteSpace, VHDLKeywords.If)
	EndPackage =        Sequence(VHDLKeywords.End, Rules.WhiteSpace, VHDLKeywords.Package)
	EndPackageBody =    Sequence(VHDLKeywords.End, Rules.WhiteSpace, VHDLKeywords.Package, Rules.WhiteSpace, VHDLKeywords.Body)
	EndEntity =          Sequence(VHDLKeywords.End, Rules.WhiteSpace, VHDLKeywords.Entity)
	EndArchitecture =    Sequence(VHDLKeywords.End, Rules.WhiteSpace, VHDLKeywords.Architecture)
	
	GenericMap =        Sequence(VHDLKeywords.Generic, VHDLKeywords.Map)
	PortMap =            Sequence(VHDLKeywords.Port, VHDLKeywords.Map)
	
	