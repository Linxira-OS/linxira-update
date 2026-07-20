complete -c linxira-update -f

complete -c linxira-update -s c -l check -d 'Check for available updates'
complete -c linxira-update -s l -l list -d 'Display the list of pending updates'
complete -c linxira-update -s d -l devel -d 'Include AUR development packages updates'
complete -c linxira-update -s n -l news -d 'Display latest Arch news'
complete -c linxira-update -s s -l services -d 'Check for services requiring a post upgrade restart'
complete -c linxira-update -s D -l debug -d 'Display debug traces'
complete -c linxira-update -l gen-config -d 'Generate a default / example configuration file'
complete -c linxira-update -l show-config -d 'Display the current configuration file'
complete -c linxira-update -l edit-config -d 'Edit the current configuration file'
complete -c linxira-update -l tray -d 'Launch the Linxira Update systray applet'
complete -c linxira-update -s h -l help -d 'Display the help message'
complete -c linxira-update -s V -l version -d 'Display version information'
