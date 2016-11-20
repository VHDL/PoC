# -*- coding: utf-8 -*-
"""
    sphinxcontrib.textstyle
    ~~~~~~~~~~~~~~~~~~~~~~~~

    :copyright: Copyright 2013 by WAKAYAMA Shirou
    :license: BSD, see LICENSE for details.
"""

import re

from docutils import nodes, utils
from sphinx.util.compat import Directive
from sphinx.util.nodes import split_explicit_title


# ==============================================================================
class RubyTag(nodes.General, nodes.Element):
    pass


def visit_rubytag_node(self, node):
    if node.rt is None:  # if rt is not set, just write rb.
        self.body.append(node.rb)
        return

    try:
        self.body.append(self.starttag(node, 'ruby'))
        self.body.append(self.starttag(node, 'rb'))
        self.body.append(node.rb)
        self.body.append('</rb>')
        self.body.append(self.starttag(node, 'rp'))
        self.body.append(node.rp_start)
        self.body.append('</rp>')
        self.body.append(self.starttag(node, 'rt'))
        self.body.append(node.rt)
        self.body.append('</rt>')
        self.body.append(self.starttag(node, 'rp'))
        self.body.append(node.rp_end)
        self.body.append('</rp>')
        self.body.append('</ruby>')
    except:
        self.builder.warn('fail to load rubytag: %r' % node)
        raise nodes.SkipNode


def depart_rubytag_node(self, node):
    pass


def rubytag_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    """Role for rubytag."""
    text = utils.unescape(text)
    has_explicit, rb, rt = split_explicit_title(text)

    config = inliner.document.settings.env.config

    rubytag = RubyTag()
    rubytag.rb = rb
    rubytag.rt = rt
    rubytag.rp_start = config.rubytag_rp_start
    rubytag.rp_end = config.rubytag_rp_end

    if not has_explicit:
        rubytag.rt = None

    return [rubytag], []


# ==============================================================================
class DelTag(nodes.General, nodes.Element):
    pass


def visit_deltag_node(self, node):
    try:
        self.body.append(self.starttag(node, 'del'))
        self.body.append(node.text)
        self.body.append('</del>')
    except:
        self.builder.warn('fail to load deltag: %r' % node)
        raise nodes.SkipNode


def depart_deltag_node(self, node):
    pass


def deltag_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    """Role for deltag."""
    text = utils.unescape(text)

    deltag = DelTag()
    deltag.text = text

    return [deltag], []


class DelDirective(Directive):
    has_content = True

    def run(self):
        deltag = DelTag()
        # delete first line which is option
        deltag.text = '\n'.join(self.content[1:])
        return [deltag]


# ==============================================================================
class Color(nodes.General, nodes.Element):
    pass


def visit_color_node(self, node):
    if node.color is None:  # if not set, just write text.
        self.body.append(node.text)
        return

    try:
        self.body.append(self.starttag(node, 'span',
                                       node.text,
                                       style="color: " + node.color))
        self.body.append('</span>')
    except Exception as e:
        self.builder.warn('fail to load color: %r' % node)
        raise nodes.SkipNode


def depart_color_node(self, node):
    pass


def color_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    """Role for color."""
    text = utils.unescape(text)
    has_explicit, text, arg = split_explicit_title(text)

    color = Color()
    color.text = text
    color.color = arg

    if not has_explicit:
        color.color = None

    return [color], []



# ==============================================================================
def setup(app):
    # rubytag
    app.add_role('ruby', rubytag_role)
    app.add_node(RubyTag,
             html=(visit_rubytag_node, depart_rubytag_node),
             epub=(visit_rubytag_node, depart_rubytag_node))
    app.add_config_value('rubytag_rp_start', '(', 'env')
    app.add_config_value('rubytag_rp_end', ')', 'env')

    # deltag
    app.add_role('del', deltag_role)
    app.add_node(DelTag,
             html=(visit_deltag_node, depart_deltag_node),
             epub=(visit_deltag_node, depart_deltag_node))
    app.add_directive('del', DelDirective)

    # style="color"
    app.add_role('color', color_role)
    app.add_node(Color,
             html=(visit_color_node, depart_color_node),
             epub=(visit_color_node, depart_color_node))
