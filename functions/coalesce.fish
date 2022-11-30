function coalesce
    # coalesce returns the first non-empty argument passed to it
    for x in $argv
        if test -n "$x"
            echo "$x"
            return
        end
    end
end
