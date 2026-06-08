# `dense` heuristic evolution — mis seed 0

### gen01 → gen02  (system 1, integration 3, unit 9 (13/13 total))

```diff
--- dense@gen01
+++ dense@gen02
@@ -1,2 +1,15 @@
 def priority(v, graph):
-    return 0.0
+    available = graph.state['available']
+    # Residual degree: number of available neighbors
+    residual_deg = sum(1 for u in graph.neighbors(v) if u in available)
+    # Prefer vertices with fewer available neighbors (lower residual degree)
+    # Use negative residual degree as priority (higher priority = lower residual degree)
+    # Also consider second-order: sum of residual degrees of available neighbors
+    neighbor_residual_sum = 0
+    for u in graph.neighbors(v):
+        if u in available:
+            neighbor_residual_sum += sum(1 for w in graph.neighbors(u) if w in available)
+    
+    # Primary: minimize residual degree
+    # Secondary: minimize sum of neighbors' residual degrees (saturation-like)
+    return -residual_deg - 0.01 * neighbor_residual_sum
```
