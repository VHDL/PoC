#!/bin/bash
echo "git config --global alias.tree 'log --decorate --pretty=oneline --abbrev-commit --date-order --graph'"
git config --global alias.tree 'log --decorate --pretty=oneline --abbrev-commit --date-order --graph'

echo "git config --global alias.treea 'log --decorate --pretty=oneline --abbrev-commit --date-order --graph' --all"
git config --global alias.treea 'log --decorate --pretty=oneline --abbrev-commit --date-order --graph --all'
