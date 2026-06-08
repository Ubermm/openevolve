# `clustered` heuristic evolution — maxcut seed 0

### gen01 → gen02  (system 1, integration 1, unit 7 (9/13 total))

```diff
--- clustered@gen01
+++ clustered@gen02
@@ -1,2 +1,21 @@
 def priority(v, graph):
-    return 0.0
+    gain_v = graph.state['gain'][v]
+    side_v = graph.state['side'][v]
+    
+    # Secondary: sum of gains of same-side neighbors
+    # When we flip v, neighbors on same side gain more incentive to flip too
+    neighbor_gain_sum = 0.0
+    same_side_weight = 0.0
+    
+    for u in graph.neighbors(v):
+        w = graph.weight(v, u)
+        if graph.state['side'][u] == side_v:
+            same_side_weight += w
+            # This neighbor might benefit from v flipping
+            neighbor_gain_sum += graph.state['gain'][u]
+    
+    # Primary: gain (steepest ascent)
+    # Secondary: encourage flipping vertices in tight clusters (many same-side neighbors)
+    # Tertiary: sum of neighbor gains (lookahead)
+    
+    return gain_v + 0.001 * same_side_weight + 0.0001 * neighbor_gain_sum
```
