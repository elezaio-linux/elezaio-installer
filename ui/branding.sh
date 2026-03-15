#!/bin/bash
# Elezaio Installer - Branding & Theme

export NEWT_COLORS='
root=black,black
window=white,#1e1e2e
border=cyan,#1e1e2e
title=cyan,#1e1e2e
button=black,#89b4fa
actbutton=black,#b4d0fb
compactbutton=black,#89b4fa
listbox=white,#181825
actlistbox=black,#89b4fa
actsellistbox=black,#89b4fa
textbox=white,#1e1e2e
acttextbox=white,#313244
entry=white,#313244
disentry=white,#45475a
label=cyan,#1e1e2e
emptyscale=white,#313244
fullscale=black,#89b4fa
helpline=white,#181825
roottext=white,#181825
'

_title="  $INSTALLER_TITLE — $INSTALLER_VERSION \"$INSTALLER_CODENAME\"  "
_btitle="Elezaio Linux $INSTALLER_VERSION"

branded_dialog() {
    whiptail --title "$_title" --backtitle "$_btitle" "$@"
}
