#!/bin/bash
# Elezaio Installer - Branding & Theme (gum)

# Gum color constants
GUM_ACCENT="99"       # purple
GUM_SUBTLE="240"      # gray
GUM_DANGER="160"      # red

_title="$INSTALLER_TITLE — $INSTALLER_VERSION \"$INSTALLER_CODENAME\""
_btitle="Elezaio Linux $INSTALLER_VERSION"

# Print a styled header
print_header() {
    clear
    gum style \
        --align center \
        --width 60 \
        --margin "1 0" \
        --padding "1 4" \
        --border rounded \
        --border-foreground "$GUM_ACCENT" \
        --foreground "$GUM_ACCENT" \
        "$_title"
}

# Show a spinner while running a command
run_with_spinner() {
    local msg="$1"
    shift
    gum spin --spinner dot \
        --title "$msg" \
        --spinner.foreground "$GUM_ACCENT" \
        -- "$@"
}

# Show an error and exit
die() {
    gum style \
        --foreground "$GUM_DANGER" \
        --border rounded \
        --border-foreground "$GUM_DANGER" \
        --padding "1 4" \
        --margin "1 0" \
        "ERROR: $*"
    exit 1
}
