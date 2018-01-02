#!/bin/bash

set -e

apt-get -qq update
apt-get install -y hunspell hunspell-ru hunspell-en-us hunspell-de-de
curl -s https://extensions.libreoffice.org/extensions/russian-spellcheck-dictionary.-based-on-works-of-aot-group > .dict_page
cat .dict_page | grep -oP "<a href.+title=\"Current release for the project\"" | grep -oP "https://extensions.libreoffice.org/extensions/russian-spellcheck-dictionary.-based-on-works-of-aot-group/[^\"]+" > .current_release
echo -n $(cat .current_release) > .current_release
echo -n "/@@download[^\"]+" >> .current_release
cat .dict_page | grep -oP -f .current_release | wget -q -i - -O dictionary.otx
unzip dictionary.otx
git config --global core.quotepath false
go get -u github.com/russross/blackfriday-tool
