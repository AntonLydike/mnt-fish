function shorten_path
    # shorten_path is a script to compress a path without sacrificing to much readibility
    # It shortens each segment in a path to one character except the last
    # It also replaces /home/user with ~ to save space
    # e.g.:
    # /path/to/somewhere        → /p/t/somewhere
    # some/relative/path        → s/r/path
    # singel_segment_path       → singel_segment_path
    # /path/with//empty/space   → /p/w//e/space
    # /home/user/test/123       → ~/t/123

    # handle single segment paths (don't contain a slash)
    if ! string match -q -- '*/*' $argv[1]
        echo $argv[1]
        return
    end

    # replace /home/<username> with ~
    set argv[1] (string replace -r "^$HOME" '~' "$argv[1]")

    # split
    set -l segments (string split '/' (string trim -r -c '/' "$argv[1]"))
    
    # handle relative paths
    if test -n "$segments[1]"
        echo -n (string split '' $segments[1])[1]
    end

    # print shortened segments
    for seg in $segments[2..-2]
        echo -n '/'(string split '' $seg)[1]
    end

    # print final segment
    echo '/'$segments[-1]
end