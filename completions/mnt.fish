complete -c mnt -f

# add flags

complete -c mnt -s h -l help -d 'Print a short help text and exit'
complete -c mnt -s l -l list -d 'List information on all available mounts'
complete -c mnt -s f -l full-paths -d 'Print full paths instead of the shorter versions'
complete -c mnt -s u -l unmount -d 'Unmount a volume' -a "(_mnt_complete_volumes unmount)"

complete -c mnt -n 'not _mnt_seen_flag u unmount; and _mnt_not_seen_any_arg' -a '(_mnt_complete_volumes mount)'

complete -c mnt -n '_mnt_seen_flag u unmount; and _mnt_not_seen_any_arg' -a '(_mnt_complete_volumes unmount)'


function _mnt_complete_volumes
    for line in (mnt_core_list_mounts | mnt_core_filter $argv[1])
        mnt_core_pretty_print_line $argv[1] $line
    end
end


function _mnt_seen_flag
    # usage: _mnt_seen_flag <shorthand> <longhand>
    # short/longhand without leading dashes
    set -l cmd (commandline -po)
    set -e cmd[1]

    if string match -r -- '^(-[^-]*'"$argv[1]"'[^-]*|--'"$argv[2]"')$' $cmd
        return 0
    end
    return 1
end

function _mnt_not_seen_any_arg
    set -l cmd (commandline -po)
    set -e cmd[1]

    if not string match -v -- '-*' $cmd
        return 0
    else
        return 1
    end
end