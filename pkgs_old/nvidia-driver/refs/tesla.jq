map_values({
    type: .type | rtrimstr(" branch"),
    version: .driver_info | max_by(.release_date) | .release_version
})

map_values({
    type: .type | rtrimstr(" branch"),
    version: .driver_info | sort_by(.release_date) | map(.release_version) | reverse,
    architectures: .driver_info[0].architectures
})