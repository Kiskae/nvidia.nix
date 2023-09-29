split("\n") | map(
    select([startswith("#"), length == 0] | any | not) |
    split(" ")
) | reduce .[] as [$branch, $maturity, $version] ({}; ."\($branch)"."\($maturity)" = "\($version)")