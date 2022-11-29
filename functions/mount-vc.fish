# mount veracrypt volumes using keyfiles or passphrases
function mount-vc --argument device key_name target -d "Mount a veracrypt container with a keyfile stored in /home/anton/.keys"
	if test -z "$argv[1]" -o \( "$argv[1]" = "--help" \) -o  \( "$argv[1]" = "-h" \)
		echo -e "mount-vc: Mount or dismount veracrypt volumes\n\
\n\
Usage:\n\
mount a volume using a keyfile:\n\
\n\
	mount-vc <device> <key file name> <target>\n\
\n\
mount a volume using a password: (will be prompted for)\n\
\n\
	mount-vc <device> <target>\n\
\n\
dismount a volume:\n\
\n\
	mount-vc -u <target>\n"
		return
	end


	if test "$argv[1]" = "-u"
		sudo veracrypt -d "$argv[2]"
		return
	end
		
	set dev "$argv[1]"
	set target "$argv[3]"
	set opts "-t" "--non-interactive"

	if test (count $argv) = 2
		read -s -P "Volume password: " pass
		set target "$argv[2]"
		set -a opts "--password=$pass"
	else
		set -a opts "-k" "$HOME/.keys/$argv[2]" "-p" ""
	end
 	sudo veracrypt $opts "$dev" "$target"
end
