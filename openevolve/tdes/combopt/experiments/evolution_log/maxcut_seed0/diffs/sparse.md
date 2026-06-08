# `sparse` heuristic evolution — maxcut seed 0

### gen01 → gen02  (system 1, integration 1, unit 7 (9/13 total))

```diff
--- sparse@gen01
+++ sparse@gen02
@@ -1,2 +1,28 @@
 def priority(v, graph):
-    return 0.0
+    gain = graph.state['gain'][v]
+    side_v = graph.state['side'][v]
+    
+    # Secondary: sum of weights to neighbors on the opposite side
+    # (flipping v makes these edges go from cut to non-cut, benefiting those neighbors)
+    # We prefer vertices where flipping helps future moves
+    # Actually prefer vertices where neighbors on same side have high weight
+    # (they will gain cut edges after v flips)
+    
+    same_side_weight = 0.0
+    opp_side_weight = 0.0
+    for u in graph.neighbors(v):
+        w = graph.weight(u, v)
+        if graph.state['side'][u] == side_v:
+            same_side_weight += w
+        else:
+            opp_side_weight += w
+    
+    # gain = opp_side_weight - same_side_weight (approximately)
+    # For tie-breaking: prefer higher degree (more influence) or 
+    # prefer vertices that free up more future improvements
+    # Neighbors on same side will become cut after flip -> they benefit
+    
+    degree = graph.degree(v)
+    
+    # Use gain as primary, same_side_weight as secondary (higher = more neighbors benefit)
+    return gain * 1000 + same_side_weight
```
