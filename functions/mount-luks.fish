function mount-luks

    argparse 'u/unmount' 'h/help' -- $argv

    if set -q _flag_help
        echo "mount-luks - mount and unmount luks containers"
        echo 
        echo "Usage for mounting: mount-luks BLOCK_DEVICE PASS_NAME MAPPER_NAME"
        echo "      where PASS_NAME is the name of the pass(1) key that contains the volume password"
        echo "      and MAPPER_NAME is the name of the luks mapper (required for unmounting)"
        return 0
    end

    if set -q _flag_unmount
        if test (count $argv) -lt 1 -o -z "$argv[1]"
            echo "Usage: mount-luks -u MAPPTER_NAME"
        end

        set -l mapper $argv[1]

        udisksctl unmount -b /dev/mapper/$mapper
        sudo cryptsetup luksClose $mapper
    else
        if test (count $argv) -lt 3
            echo "Usage: mount-luks BLOCK_DEVICE PASS_NAME MAPPER_NAME"
        end

        set -l device $argv[1]
        set -l pass_name $argv[2]
        set -l mapper $argv[3]

        pass $pass_name | head -n 1 | sudo cryptsetup luksOpen $device $mapper -
        udisksctl mount -b /dev/mapper/$mapper
    end
end
