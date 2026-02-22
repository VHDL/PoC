# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
from sys import path as sys_path
from os.path import abspath
from pathlib import Path

from pyTooling.Packaging import extractVersionInformation

ROOT = Path(__file__).resolve().parent

sys_path.insert(0, abspath("."))
sys_path.insert(0, abspath(".."))
sys_path.insert(0, abspath("../py"))
sys_path.insert(0, abspath("_extensions"))


# ==============================================================================
# Project information and versioning
# ==============================================================================
# The version info for the project you're documenting, acts as replacement for
# |version| and |release|, also used in various other places throughout the
# built documents.
githubNamespace = "VHDL"
project = "PoC"

# packageInformationFile = Path(f"../{project}/__init__.py")
# versionInformation = extractVersionInformation(packageInformationFile)
#
# author =    versionInformation.Author
# copyright = versionInformation.Copyright
# version =   ".".join(versionInformation.Version.split(".")[:2])  # e.g. 2.3    The short X.Y version.
# release =   versionInformation.Version
# project = 'The PoC-Library'
copyright = '2007-2016 Technische Universitaet Dresden - Germany, Chair of VLSI-Design, Diagnostics and Architecture'
author = 'The PoC-Library Authors'

version = "2.2"     # The short X.Y version.
release = "2.2.0"   # The full version, including alpha/beta/rc tags.

from subprocess import check_output

def _IsUnderGitControl():
	return (check_output(["git", "rev-parse", "--is-inside-work-tree"], universal_newlines=True).strip() == "true")

def _LatestTagName():
	return check_output(["git", "describe", "--abbrev=0", "--tags"], universal_newlines=True).strip()

try:
	if _IsUnderGitControl:
		latestTagName = _LatestTagName()[1:]		# remove prefix "v"
		versionParts =  latestTagName.split("-")[0].split(".")

		version = ".".join(versionParts[:2])
		release = latestTagName   # ".".join(versionParts[:3])
except:
	pass

# for tag in tags:
# 	print(tag)
#
# # if (not (tags.has('PoCExternal') or tags.has('PoCInternal'))):
# 	# tags.add('PoCExternal')
#
# from pathlib  import Path
# from shutil   import rmtree as shutil_rmtree
#
# if tags.has('PoCCleanUp'):
# 	buildDirectory = Path("_build")
# 	if (buildDirectory.exists()):
# 		print("Removing old build directory '{0!s}'...".format(buildDirectory))
# 		shutil_rmtree(str(buildDirectory))
# 	else:
# 		print("Removing old build directory '{0!s}'... [SKIPPED]".format(buildDirectory))
#
# 	pyInfrastructureDirectory = Path("PyInfrastructure")
# 	print("Removing created files from '{0!s}'...".format(pyInfrastructureDirectory))
# 	for path in pyInfrastructureDirectory.iterdir():
# 		if (path.name.endswith(".rst") and (path.name != (pyInfrastructureDirectory / "index.rst"))):
# 			print("  {0!s}".format(path))
# 			path.unlink()
# 	print()


# ==============================================================================
# Miscellaneous settings
# ==============================================================================
# The master toctree document.
master_doc = "index"

# Add any paths that contain templates here, relative to this directory.
templates_path = ["_templates"]

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = [
	"_build",
	"_theme",
	"Thumbs.db",
	".DS_Store"
]

# The name of the Pygments (syntax highlighting) style to use.
pygments_style = "manni"


# ==============================================================================
# Restructured Text settings
# ==============================================================================
prologPath = Path("prolog.inc")
try:
	with prologPath.open("r", encoding="utf-8") as fileHandle:
		rst_prolog = fileHandle.read()
except Exception as ex:
	print(f"[ERROR:] While reading '{prologPath}'.")
	print(ex)
	rst_prolog = ""


# ==============================================================================
# Options for HTML output
# ==============================================================================
html_theme = "sphinx_rtd_theme"
html_theme_options = {
	"logo_only": True,
	"vcs_pageview_mode": 'blob',
	"navigation_depth": 5,
}
html_css_files = [
	'css/override.css',
]

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = ["_static"]

html_logo = str(Path(html_static_path[0]) / "icons/The-PoC-Library-Icon.png")
html_favicon = str(Path(html_static_path[0]) / "icons/The-PoC-Library-FavIcon.png")

# Output file base name for HTML help builder.
htmlhelp_basename = f"{project}Doc"

# If not None, a 'Last updated on:' timestamp is inserted at every page
# bottom, using the given strftime format.
# The empty string is equivalent to '%b %d, %Y'.
html_last_updated_fmt = "%d.%m.%Y"

# ==============================================================================
# Python settings
# ==============================================================================
modindex_common_prefix = [
	f"{project}."
]

# ==============================================================================
# Options for LaTeX / PDF output
# ==============================================================================
from textwrap import dedent

latex_elements = {
	# The paper size ('letterpaper' or 'a4paper').
	"papersize": "a4paper",

	# The font size ('10pt', '11pt' or '12pt').
	#'pointsize': '10pt',

	# Additional stuff for the LaTeX preamble.
	"preamble": dedent(r"""
		% ================================================================================
		% User defined additional preamble code
		% ================================================================================
		% Add more Unicode characters for pdfLaTeX.
		% - Alternatively, compile with XeLaTeX or LuaLaTeX.
		% - https://GitHub.com/sphinx-doc/sphinx/issues/3511
		%
		\ifdefined\DeclareUnicodeCharacter
			\DeclareUnicodeCharacter{2265}{$\geq$}
			\DeclareUnicodeCharacter{21D2}{$\Rightarrow$}
		\fi


		% ================================================================================
		"""),

	# Latex figure (float) alignment
	#'figure_align': 'htbp',
}

# Grouping the document tree into LaTeX files. List of tuples
# (source start file, target name, title,
#  author, documentclass [howto, manual, or own class]).
latex_documents = [
	( master_doc,
		f"{project}.tex",
		f"The PoC Library Documentation",
		f"Patrick Lehmann, Thomas B. Preusser, Martin Zabel",
		f"manual"
	),
]


# ==============================================================================
# Extensions
# ==============================================================================
extensions = [
# Standard Sphinx extensions
	"sphinx.ext.autodoc",
	"sphinx.ext.extlinks",
	"sphinx.ext.intersphinx",
	"sphinx.ext.inheritance_diagram",
	"sphinx.ext.todo",
	"sphinx.ext.graphviz",
	"sphinx.ext.mathjax",
	"sphinx.ext.ifconfig",
	"sphinx.ext.viewcode",
# SphinxContrib extensions
	"sphinxcontrib.mermaid",
	"sphinxcontrib.autoprogram",
# autoprogram or sphinxcontrib.autoprogram
# Other extensions
	"sphinx_design",
	"sphinx_copybutton",
	"sphinx_autodoc_typehints",
	"autoapi.sphinx",
	"sphinx_reports",
	# "pyEDAA.OSVVM.Sphinx",
#	"wavedrom",
# User defined extensions
# 	'DocumentMember',
# 	'poc'
]


# ==============================================================================
# Sphinx.Ext.InterSphinx
# ==============================================================================
intersphinx_mapping = {
	"python": ("https://docs.python.org/3", None),
	'ghdl':   ('https://ghdl.github.io/ghdl', None)
}


# ==============================================================================
# Sphinx.Ext.AutoDoc
# ==============================================================================
# see: https://www.sphinx-doc.org/en/master/usage/extensions/autodoc.html#configuration
#autodoc_default_options = {
#	"private-members": True,
#	"special-members": True,
#	"inherited-members": True,
#	"exclude-members": "__weakref__"
#}
#autodoc_class_signature = "separated"
autodoc_member_order = "bysource"       # alphabetical, groupwise, bysource
autodoc_typehints = "both"
#autoclass_content = "both"


# ==============================================================================
# Sphinx.Ext.ExtLinks
# ==============================================================================
extlinks = {
	"gh":       (f"https://GitHub.com/%s", "gh:%s"),
	"ghissue":  (f"https://GitHub.com/{githubNamespace}/{project}/issues/%s", "issue #%s"),
	"ghpull":   (f"https://GitHub.com/{githubNamespace}/{project}/pull/%s", "pull request #%s"),
	"ghsrc":    (f"https://GitHub.com/{githubNamespace}/{project}/blob/master/%s", None),
	"wiki":     (f"https://en.wikipedia.org/wiki/%s", None),

	"pocissue": (f"https://github.com/{githubNamespace}/{project}/issues/%s", 'issue #%s'),           # => replace by ghissue
	"pocpull":  (f"https://github.com/{githubNamespace}/{project}/pull/%s", 'pull request #%s'),      # => replace by ghpull
	"pocsrc":   (f"https://github.com/{githubNamespace}/{project}/blob/master/src/%s?ts=2", None),  # => replace by ghsrc
	"poctb":    (f"https://github.com/{githubNamespace}/{project}/blob/master/tb/%s?ts=2", None)
}


# ==============================================================================
# Sphinx.Ext.Graphviz
# ==============================================================================
graphviz_output_format = "svg"


# ==============================================================================
# SphinxContrib.Mermaid
# ==============================================================================
mermaid_params = [
	'--backgroundColor', 'transparent',
]
mermaid_verbose = True


# ==============================================================================
# Sphinx.Ext.Inheritance_Diagram
# ==============================================================================
inheritance_node_attrs = {
#	"shape": "ellipse",
#	"fontsize": 14,
#	"height": 0.75,
	"color": "dodgerblue1",
	"style": "filled"
}


# ==============================================================================
# Sphinx.Ext.ToDo
# ==============================================================================
# If true, `todo` and `todoList` produce output, else they produce nothing.
todo_include_todos = True
todo_link_only = True


# ==============================================================================
# sphinx-reports
# ==============================================================================
report_unittest_testsuites = {
	"src": {
		"name":        f"{project}",
		"xml_report":  "../report/unit/unittest.xml",
	}
}

# report_codecov_packages = {
# 	"src": {
# 		"name":        f"{project}",
# 		"json_report": "../report/coverage/coverage.json",
# 		"fail_below":  80,
# 		"levels":      "default"
# 	}
# }
# report_doccov_packages = {
# 	"src": {
# 		"name":       f"{project}",
# 		"directory":  f"../{project}",
# 		"fail_below": 80,
# 		"levels":     "default"
# 	}
# }

osvvm_build_summaries = {
	"PoC": {
		"name":        "The PoC-Library",
		"yaml_report": "../report/unit/osvvmreport.yml",
	}
}

# ==============================================================================
# Sphinx_Design
# ==============================================================================
# sd_fontawesome_latex = True


# ==============================================================================
# AutoAPI.Sphinx
# ==============================================================================
# autoapi_modules = {
# 	f"{project}":  {
# 		"template": "package",
# 		"output":   project,
# 		"override": True
# 	}
# }
#
# for directory in [mod for mod in Path(f"../{project}").iterdir() if mod.is_dir() and mod.name != "__pycache__"]:
# 	print(f"Adding module rule for '{project}.{directory.name}'")
# 	autoapi_modules[f"{project}.{directory.name}"] = {
# 		"template": "module",
# 		"output":   project,
# 		"override": True
# 	}


# ==============================================================================
# Custom changes
# ==============================================================================
def setup(app):
	# app.add_stylesheet('css/custom.css')

	if tags.has('PoCInternal'):
		app.add_config_value('visibility', 'PoCInternal', True)
		print("="* 40)
	else:
		app.add_config_value('visibility', 'PoCExternal', True)
		print("-"* 40)
