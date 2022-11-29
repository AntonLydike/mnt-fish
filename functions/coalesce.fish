function coalesce
    for x in $argv
        if test -n "$x"
            echo "$x"
            return
        end
    end
end
