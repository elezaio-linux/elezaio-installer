#!/bin/bash
# Elezaio Installer - Branding & Colors

export INSTALLER_TITLE="Elezaio Linux Installer"
export INSTALLER_VERSION="2026.3r11"
export INSTALLER_CODENAME="Nova"

# Whiptail colors via NEWT_COLORS
export NEWT_COLORS='
root=white,black
border=black,black
window=white,black
shadow=black,black
title=cyan,black
button=black,cyan
actbutton=white,blue
checkbox=white,black
actcheckbox=black,cyan
entry=white,black
label=cyan,black
listbox=white,black
actlistbox=black,cyan
textbox=white,black
acttextbox=black,cyan
helpline=white,black
roottext=white,black
'

# Helper: show branded dialog
branded_dialog() {
    local type="$1"
    local title="$2"
    local msg="$3"
    shift 3
    whiptail --title "  $INSTALLER_TITLE  " \
             --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
             "--$type" "$msg" 20 70 "$@"
}
