# `clustered` heuristic evolution — mis seed 0

### gen01 → gen02  (system 1, integration 3, unit 9 (13/13 total))

```diff
--- clustered@gen01
+++ clustered@gen02
@@ -1,2 +1,29 @@
 def priority(v, graph):
-    return 0.0
+    available = graph.state['available']
+    
+    # Compute residual degree (number of available neighbors)
+    neighbors_v = graph.neighbors(v)
+    residual_deg = sum(1 for u in neighbors_v if u in available)
+    
+    # We want LOW residual degree -> HIGH priority, so negate
+    # Tie-break: prefer vertices whose available neighbors have high residual degrees
+    # (taking v removes high-cost neighbors, freeing the graph)
+    
+    # Secondary: sum of residual degrees of neighbors (higher = better to take v)
+    neighbor_residual_sum = 0
+    for u in neighbors_v:
+        if u in available:
+            neighbor_residual_sum += sum(1 for w in graph.neighbors(u) if w in available)
+    
+    # Primary: minimize residual degree (negate for max priority)
+    # Secondary: maximize neighbor residual sum (taking v removes high-degree neighbors)
+    # Tertiary: use static degree as further tiebreak
+    
+    # Combine: primary is -residual_deg, secondary is neighbor_residual_sum
+    # Scale to combine: residual_deg is at most n, neighbor_residual_sum is at most n^2
+    # Use a large multiplier for primary signal
+    
+    primary = -residual_deg
+    secondary = neighbor_residual_sum / (graph.n * graph.n + 1)
+    
+    return primary + secondary
```
