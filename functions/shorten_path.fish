function shorten_path
    if ! string match -q -- '*/*' $argv[1]
        echo $argv[1]
        return
    end

    set -l segments (string split '/' (string trim -r -c '/' $argv[1]))
    
    if test -n $segments[1]
        echo -n (string split '' $segments[1])[1]
    end

    for seg in $segments[2..-2]
        echo -n '/'(string split '' $seg)[1]
    end
    echo '/'$segments[-1]
end