#!/bin/bash
# Elezaio Installer - Branding & Theme

export NEWT_COLORS='
root=white,black
window=white,black
border=white,black
shadow=black,black
title=white,black
button=black,white
listbox=white,black
actlistbox=black,cyan
actsellistbox=black,cyan
textbox=white,black
acttextbox=black,cyan
entry=black,white
disentry=gray,black
label=white,black
emptyscale=black,black
fullscale=black,cyan
helpline=black,cyan
roottext=white,black
checkbox=white,black
actcheckbox=black,cyan
'

_title="  $INSTALLER_TITLE — $INSTALLER_VERSION \"$INSTALLER_CODENAME\"  "
_btitle="Elezaio Linux $INSTALLER_VERSION"

branded_dialog() {
    whiptail --title "$_title" --backtitle "$_btitle" "$@"
}
