#!/usr/bin/perl -w
# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t; perl-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:               Thomas B. Preusser
#
# Description:
# ------------
# This is a filter that simplifies boolean expressions within VHDL sources.
# In particular it eliminates verbose comparisons with the boolean literals
# 'true' and 'false' and removes obvious extraneous parentheses, e.g.
# enclosing a complete 'if' condition.
#
# License:
# --------
# Copyright 2016-2016 Technische Universitaet Dresden - Germany
#                     Chair of VLSI-Design, Diagnostics and Architecture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

use strict;
use warnings;
use Parse::RecDescent;
use feature 'state';

# Provide ::dump($var) for debugging purposes.
#
# use Data::Dumper;
# $Data::Dumper::Indent = 1;
# $Data::Dumper::Sortkeys = 1;
# sub dump {
#   print Dumper $_[0];
# }
#$RD_HINT = 1;

sub reduce_left {
  my($type, $left, $rght, $key) = @_;
  if(@{$rght}) {
    for my $iter (@{$rght}) {
      push @{$left->{'del'}}, @{$iter->{$key}{'del'}}
    }
    $left->{'type'} = $type;
  }
  $left
}

sub del_range {
  my $to = $_[2]? $_[2] : $_[1]+1;
  my($pre, $post) = (substr($_[0], 0, $_[1]), substr($_[0], $to) =~ s/^\s+//r);
  $pre .= ' ' if $pre =~ /\w$/ and $post =~ /^\w/;
  $pre.$post
}

sub and_close {
  my $e = &{splice(@_,1,1)};
  (substr($e, 0, $_[1]) =~ s/\s*$//r).')'.substr($e, $_[1])
}

sub insert {
  my $pre = substr($_[0], 0, $_[1]);
  $pre .= ' ' if $pre =~ /\w$/;
  $pre.$_[2].(substr($_[0], $_[1]) =~ s/^\s*//r)
}

my $grammar = q{
<autotree>

startrule: logi { $text =~ /^\s*$/? $item[1] : undef }

logi : cmp (/n?(and|or)|xn?or/ cmp)(s?) { ::reduce_left(@item, 'cmp') }

cmp : shft cmp_ext(s?) {
  my($type, $left, $rght) = @item;
  if(@{$rght}) {
    for my $iter (@{$rght}) {
      if($iter->{'type'} eq 'inv') {
        if($left->{'type'} =~ /lit|par/) {
          push @{$left->{'del'}}, [\&::insert, $itempos[1]->{'offset'}{'from'}, 'not '];
        }
        else {
          push @{$left->{'del'}}, [\&::insert, $itempos[1]->{'offset'}{'from'}, 'not('];
          unshift @{$iter->{'del'}[0]}, \&::and_close;
        }
      }
      else {
        $left->{'type'} = $type unless $iter->{'type'} eq 'nop';
      }
      push @{$left->{'del'}}, @{$iter->{'del'}};
    }
  }
  $left
}

cmp_ext : /[<=>]|[<\/>]=/ shft {
  if(($item[1] eq  '=') && ($item[2]->{'type'} eq 'true') or
     ($item[1] eq '/=') && ($item[2]->{'type'} eq 'false')) {
    push @{$item[2]->{'del'}}, [\&::del_range, $itempos[1]->{'offset'}{'from'}, $itempos[2]->{'offset'}{'to'}+1];
    $item[2]->{'type'} = 'nop';
  }
  if(($item[1] eq  '=') && ($item[2]->{'type'} eq 'false') or
     ($item[1] eq '/=') && ($item[2]->{'type'} eq 'true')) {
    push @{$item[2]->{'del'}}, [\&::del_range, $itempos[1]->{'offset'}{'from'}, $itempos[2]->{'offset'}{'to'}+1];
    $item[2]->{'type'} = 'inv';
  }
  $item[2]
}

shft : add (/s[lr][al]|ro[lr]/ add)(s?) { ::reduce_left(@item, 'add') }
add  : mul (/[&+-]/ mul)(s?)            { ::reduce_left(@item, 'mul') }
mul  : exp (/\*|\/|div|rem/ exp)(s?)    { ::reduce_left(@item, 'exp') }
exp  : lit ('**' lit)(s?)               { ::reduce_left(@item, 'lit') }

lit : /abs|not|[+-]/ <commit> lit  { { 'type' => 'pre', del => $item[-1]{'del'} } }
    | /false|true/i <commit>       { { 'type' => lc $item[1], del => [] } }
    | /\w+|".*?"/ <commit> par(s?) {
      my @del = ();
      push @del, @{$_->{'del'}} for @{$item[-1]};
      { 'type' => 'lit', del => \@del }
    }
    | par {
      if($item[1]->{'type'} =~ /lit|true|false|par/) {
        push @{$item[1]->{'del'}}, [\&::del_range, $_] for ($itempos[1]->{'offset'}{'from'}, $itempos[1]->{'offset'}{'to'});
      }
      else {
        $item[1]->{'type'} = 'par' unless $item[1]->{'type'} eq 'list';
      }
      $item[1]
    }

par : '(' logi (',' logi)(s?) ')' {
      if(@{$item[-2]}) {
        push @{$item[2]->{'del'}}, @{$_} for $item[-2][0]{'logi'}{'del'};
        $item[2]->{'type'} = 'list';
      }
      $item[2]
    }
};

sub simplify {
  state $parser = Parse::RecDescent->new($grammar);

  my $expr = $_[0];
  my $result = $parser->startrule($expr);
  return  undef unless $result;

  for my $d (sort { $$b[1] <=> $$a[1] } @{$result->{'del'}}) {
    my $f = $d->[0];
    $d->[0] = $expr;
    $expr = $f->(@$d);
  }
  $expr =~ s/^\s+//;
  $expr =~ s/\s+$//;
  $expr =~ s/^\(\s*(.*?)\s*\)$/$1/ if $result->{'type'} eq 'par';
  $expr
}

while(<>) {
  my $comment;
  chomp;
  ($_, $comment) = ($1, $2) if /^(.*?)(--.*)?$/;

  if(/^(.*\b(?:if|elsif|while)\b)\s*(.*?)\s*(\b(?:then|loop|generate)\b.*)$/x || /^(.*\bwhen\b)\s*(.*?)\s*(\belse\b.*)$/x) {
    my $res = simplify($2);
    $_ = "$1 $res $3" if $res;
  }
  if(/^(.*[<:]=\s*)(.*?)\s*(;.*)$/) {
    my $res = simplify($2);
    $_ = "$1$res$3" if $res;
  }

  $_ .= $comment if $comment;
  print "$_\n";
}
