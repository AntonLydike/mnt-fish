set _MNT_SEEN_DEVICES /dev/sda /dev/nvme0n1

function mnt

    argparse --name=mnt 'h/help' 'l/list' 'f/full-paths' 'u/unmount' -- $argv

    if set -q _flag_help
        echo "mnt - A mounting utility"
        echo 
        echo "Usage:        mnt -hlfu [IDENTIFIER]"
        echo
        echo "Flags"
        echo "        -l/--list         List information on all available mounts (default behaviour if no IDENTIFIER"
        echo "                          was specified)"
        echo
        echo "        -h/--help         Print this help page"
        echo 
        echo "        -u/--unmount      Unmount specified path"
        echo
        echo "        -f/--full-paths   Print full paths instead of the shorter versions"
        echo
        echo "IDENTIFIER"
        echo "                          The IDENTIFIER can be anything that identifies a line in the output of"
        echo "                          mnt_core_list_mounts when using grep"
        return 0
    end

    if set -q _flag_list; or ! count $argv > /dev/null
        mnt_core_pretty_list_mounts $_flag_full_paths | sort
        return 0
    end

    set -l selected_mount (mnt_core_list_mounts | rg -- (string trim -rc '/' -- $argv[1]))
    
    if test (count $selected_mount) -gt 1
        echo '"'"$argv[1]"'" is ambigous, it matched:'
        for line in $selected_mount
            echo " - "(string split \t $line)[1]
        end
        echo "Please be a little bit more precise!"
        # TODO: allow the user to select one of the options
        return 1
    end

    if test -z "$selected_mount"
        echo "Mount point not found!"
        return 1
    end


    set -l info (string split \t $selected_mount)
    set -l device $info[1]
    set -l path $info[2]

    set -l mount_point (mnt_core_mount_point $info[1])

    if set -q _flag_unmount
        if test -z "$mount_point"
            set_color red
            echo $argv[1] "might not actually be mounted!"
            set_color normal
        end
        echo $info[4]
        eval $info[4]
    else
        if test -n "$mount_point"
            echo $argv[1] "is already mounted at $mount_point!"
            return 1
        end

        echo $info[3]
        eval $info[3]
    end

end


function mnt_core_pretty_list_mounts
    argparse 'f/full-paths' -- $argv

    for line in (mnt_core_list_mounts)
        set -l info (string split \t $line)
        set -l pretty_print_mode mount
        if test -d $info[2]
            set_color green
            echo -n "[m] "
            set pretty_print_mode unmount
        else if test -b $info[1]
            set_color yellow
            echo -n "[u] "
        else
            set_color red
            echo -n "[-] "
        end
        
        set pretty (string split '\t' (mnt_core_pretty_print_line $_flag_full_paths $pretty_print_mode $line))

        if ! set -q _flag_full_paths
            set pretty[1] (shorten_path $pretty[1])
        end
        
        echo $pretty
    end
end


function mnt_core_pretty_print_line
    argparse 'f/full-paths' -- $argv

    set -l info (string split \t $argv[2])

    set -l path_printer shorten_path
    if set -q _flag_full_paths
        set path_printer echo
    end

    # unpack info
    set -l device $info[1]
    set -l mount_path $info[2]
    set -l mount_cmd $info[3]
    set -l unmount_cmd $info[4]
    set -l name (coalesce "$info[5]" ($path_printer (string replace '-' '' $mount_path)) "???")
    set -l size $info[6]
    set -l cmd "$unmount_cmd"

    # decide if to print the mount or unmount cmd
    if test $argv[1] = 'mount'
        set cmd "$mount_cmd"
    end

    set -l tab \t

    # print #name (size), but leave out missing parts
    if test -n "$size"
        if test -n "$name"
            echo "$device"\t"$name ($size)"
        else
            echo "$device"\t"($size)"
        end
    else 
        if test -n "$name"
            echo "$device"\t"$name"
        else
            echo "$device"\t"$cmd"
        end
    end
end

function mnt_core_list_mounts
    # list things defined in ~/.mounts
    set -l seen $_MNT_SEEN_DEVICES $MNT_IGNORE_DEVICES
    for line in (cat ~/.mounts)
        # filter out empty lines
        if test -z "$line"
            continue
        end
        # filter out comments
        if string match -erq '^\s*#.+' "$line" 2> /dev/null
            continue
        end

        set -l info (string split \t $line)
        set -a seen $info[1]
        set -l size (mnt_core_get_blockdevice_size $info[1])
        
        echo $line\t"$size"
    end

    mnt_core_list_block_dev $seen
end

function mnt_core_list_block_dev
    set -l seen $argv
    # iterate normal block devices (sdXN)
    for device in /dev/sd?
        if string match -q -- $device $seen
            continue
        end

        for part in $device?
            if string match -q -- $device $seen
                continue
            end
            # get the mount point, or - if it doesn't exist
            set -l mount_point (coalesce (mnt_core_mount_point $part) -)
            # get label and size
            set -l label (mnt_core_get_blockdevice_label $part)
            set -l size (mnt_core_get_blockdevice_size $part)

            echo "$part"\t"$mount_point"\tudisksctl mount -b "'$part'"\tudisksctl unmount -b $part\t"$label"\t"$size"
        end
    end
end


function mnt_core_filter
    while read line
        set -l info (string split \t $line)

        switch $argv[1]
            case available avail
                if test -b $info[1]
                    echo $line
                end
            case mounted
                if mnt_core_mount_point $info[1] > /dev/null
                    echo $line
                end
            case unmounted
                if test -b $info[1]; and ! mnt_core_mount_point $info[1] > /dev/null
                    echo $line
                end
            case '*'
                echo $line
        end
    end
end

function mnt_core_mount_point
    # get block device mount point or children mount point (if child is of type crypt)
    # it was introduced to better handle encrypted setups, where not the block device, but the crypt container is mounted
    set -l res (lsblk -J $argv 2>/dev/null | jq -r '.blockdevices[0].mountpoints[0] // ( if .blockdevices[0].children then (.blockdevices[0].children[] | select(.type == "crypt") | .mountpoints[0]) else "" end) // ""')
    if test -z "$res"
        return 1
    end
    echo $res
end

function mnt_core_get_blockdevice_size
    set -l res (lsblk -J $argv 2>/dev/null | jq -r '.blockdevices[0].size // ""')
    if test -z "$res"
        return 1
    end
    echo $res
end

function mnt_core_get_blockdevice_label
    blkid -o value --match-tag LABEL $argv
end