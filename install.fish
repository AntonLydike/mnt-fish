#!/usr/bin/env fish

function print_warn
    echo (set_color yellow)"WARN: $argv" (set_color normal)
end

function print_err
    echo (set_color red)"ERROR: $argv" (set_color normal)
end

function to_stderr
    while read -l line
        echo $line 1>&2
    end
end

function check_program_installed
    # check if program $argv[1] is installed, if not, print a warning
    if ! command -vq $argv[1]
        print_err "External program $argv[1] is required, please install it using your package manager of choice!" | to_stderr
        return 1
    end
    return 0
end

function install_symlink
    # install $argv[1] to $argv[2] using a symlink
    # return 0 if it worked or if the target exists but is a symlink to $argv[1]
    # otherwise return 1
    # (--force overwrites the behavour to overwrite install)

    argparse 'f/force' -- $argv

    if ! ln -s $flag_force $argv[1] $argv[2] 2> /dev/null
        if test (realpath $argv[2]) = $argv[1]
            return 0
        end
        print_warn "File $argv[2] already exists and is not a symlink to $argv[1]!" | to_stderr
        return 1
    end 
end

function install_copy
    # install $argv[1] to $argv[2] by copying it, doesn't overwrite if no -f/--force flag is given
    # return 1 if the file couldn't be copied

    argparse 'f/force' -- $argv

    if test -f $argv[2]; and ! set -q _flag_force
        print_warn "File $argv[2] already exists, use --force to overwrite existing files." | to_stderr
        return 1
    end

    cp $argv[1] $argv[2]
end

function uninstall_mnt
    argparse 'e/extras' -- $argv

    # uninstall mode!
    echo "Uninstalling mnt..."
    for file in $core_files $dependencies
        if test -f $fish_config_path/$file
            rm $fish_config_path/$file
            echo "  Removed $fish_config_path/$file"
        else
            echo "  $file was not installed."
        end
    end
    if set -q _flag_extras
        echo "Uninstalling extras..."
        for file in $extras
            if test -f $fish_config_path/$file
                rm $fish_config_path/$file
                echo "  Removed $fish_config_path/$file"
            else
                echo "  $file was not installed."
            end
        end
    end
end

function install
    argparse 'h/help' 'c/copy' 'f/force' 'e/extras' 'C/clean' -- $argv

    # get path to this script, which is the repo path
    set DIR (cd (dirname (status -f)); and pwd) 

    if set -q _flag_help
        echo "mnt install script:"
        echo 
        echo "Usage: ./install.sh -h/--help -c/--copy -f/--force -e/--extras -C/--clean"
        echo 
        echo "Flags:"
        echo "          -h/--help   Show this messasge"
        echo 
        echo "          -c/--copy   Copy files instead of symlinking"
        echo 
        echo "          -f/--force  Overwrite existing files"
        echo 
        echo "          -e/--extras Copy helpful extras such as mount-luks and mount-vc"
        echo 
        echo "          -C/--clean  Uninstall all installed files. Uninstalls extras when used with -e"
        echo
        return 0
    end

    set -l external_dependencies rg blkid jq udisksctl
    set -l core_files functions/mnt.fish completions/mnt.fish
    set -l dependencies functions/{coalesce,shorten_path}.fish
    set -l extras functions/{mount-luks,mount-vc}.fish
    set -l fish_config_path $HOME/.config/fish
        
    # get fish config path from argv[1]
    if test (count $argv) -gt 0
        set fish_config_path $argv[1]
    end

    # figure out the command we use for installing files
    set -l install_cmd install_symlink $_flag_force
    if set -q _flag_copy
        set install_cmd install_copy $_flag_force
    end

    # find path to fish config
    if ! test -f $fish_config_path/config.fish
        print_err "Could not find fish config at $fish_config_path/config.fish" | to_stderr
        return 1
    end

    # check for uninstall flag
    if set -q _flag_clean
        uninstall_mnt $_flag_extras
        return 0
    end

    # check external dependencies
    for dep in $external_dependencies
        check_program_installed $dep; or return 1
    end

    # install core files
    for file in $core_files
        if ! $install_cmd $DIR/$file $fish_config_path/$file
            print_err "Aborting installation..."
            return 1
        end
        set_color green
        echo "Installed $file..."
        set_color normal
    end

    # install deps
    for file in $dependencies
        if $install_cmd $DIR/$file $fish_config_path/$file
            set_color green
            echo "Installed $file..."
            set_color normal
        else
            print_warn "Could not install dependency "(basename $file)", installer will continue, but installation might be incomplete." | to_stderr
        end
    end

    # install extras if requested
    if set -q _flag_extras
        for file in $extras
            if $install_cmd $DIR/$file $fish_config_path/$file
                set_color green
                echo "Installed $file..."
                set_color normal
            else
                print_warn "Could not install extra "(basename $file)", installer will continue, but installation might be incomplete." | to_stderr
            end
        end
    end

    # install .mount file
    if test -f $HOME/.mounts
        set_color green
        echo ".mounts file already installed!"
        set_color normal
    else
        cp $DIR/.mounts $HOME/.mounts
        echo "Provided a clean .mounts file in $HOME/.mounts"
    end

    echo
    set_color green
    echo ">>> Installation complete! <<<"
    set_color normal
end


if test "$_" != source
    install $argv
    exit $status
end