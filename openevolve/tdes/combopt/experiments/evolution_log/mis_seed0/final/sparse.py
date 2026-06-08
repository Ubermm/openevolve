def priority(v, graph):
    available = graph.state['available']
    # Residual degree: number of available neighbors
    residual_deg = sum(1 for u in graph.neighbors(v) if u in available)
    # We want to prefer vertices with low residual degree (they "cost" less)
    # Also consider the sum of residual degrees of neighbors (saturation-like signal)
    neighbor_residual_sum = 0
    for u in graph.neighbors(v):
        if u in available:
            neighbor_residual_sum += sum(1 for w in graph.neighbors(u) if w in available)
    # Lower residual degree is better -> negate
    # Also lower neighbor_residual_sum is better (picking this vertex removes high-degree neighbors)
    # Use negative residual degree as primary signal, break ties with neighbor residual sum
    return -residual_deg - 0.01 * neighbor_residual_sum