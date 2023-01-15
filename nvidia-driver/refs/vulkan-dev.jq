map(select(
    .body | contains("https://developer.nvidia.com/vulkan-driver")
)) | max_by(.published_at) | { latest: .tag_name }