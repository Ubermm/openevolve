def priority(v, graph):
    gain_v = graph.state['gain'][v]
    side_v = graph.state['side'][v]
    
    # Secondary: estimate future gain impact
    # Flipping v helps same-side neighbors and hurts other-side neighbors
    future_benefit = 0.0
    for u in graph.neighbors(v):
        w = graph.weight(u, v)
        if graph.state['side'][u] == side_v:
            # u's gain increases by 2*w
            future_benefit += w
        else:
            # u's gain decreases by 2*w
            future_benefit -= w
    
    # Normalize secondary signal relative to gain magnitude
    # Use gain as primary, future_benefit as tie-breaker
    return gain_v + 0.001 * future_benefit