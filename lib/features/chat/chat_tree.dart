import 'package:dendrite/core/db/database.dart';

/// Pure tree-navigation helpers over a flat list of [Message] nodes, where each
/// node references its parent through [Message.parentId]. Kept free of UI/DB so
/// the branching logic can be unit-tested in isolation.
class ChatTree {
  /// Resolves which leaf to focus when none is explicitly active.
  ///
  /// If [activeNodeId] is provided it wins. Otherwise picks the most recent node
  /// on the "main trunk" — one whose neither self nor any ancestor carries a
  /// branch selection ([Message.associatedSelection]) — falling back to the
  /// first node. Returns null only when [nodes] is empty and nothing is active.
  static String? resolveActiveLeaf(List<Message> nodes, String? activeNodeId) {
    if (activeNodeId != null) return activeNodeId;
    if (nodes.isEmpty) return null;

    for (int i = nodes.length - 1; i >= 0; i--) {
      final candidate = nodes[i];
      if (candidate.associatedSelection == null) {
        bool hasBranchInAncestors = false;
        String? currParentId = candidate.parentId;
        while (currParentId != null) {
          final parentNode = nodes.firstWhere(
            (n) => n.id == currParentId,
            orElse: () => candidate,
          );
          if (parentNode.id == candidate.id) break; // prevent loops
          if (parentNode.associatedSelection != null) {
            hasBranchInAncestors = true;
            break;
          }
          currParentId = parentNode.parentId;
        }
        if (!hasBranchInAncestors) {
          return candidate.id;
        }
      }
    }

    // Fallback to the very first node if no clean trunk leaf was found.
    return nodes.first.id;
  }

  /// Follows the longest descendant path from [rootId] and returns its leaf id.
  static String deepestDescendant(String rootId, List<Message> nodes) {
    final Set<String> visited = {};

    String find(String id) {
      if (visited.contains(id)) return id;
      visited.add(id);

      final children = nodes.where((n) => n.parentId == id).toList();
      if (children.isEmpty) return id;

      // Select child with the maximum depth path.
      String bestChildId = children.first.id;
      int maxDepth = -1;

      int getPathDepth(String childId, Set<String> localVisited) {
        if (localVisited.contains(childId)) return 0;
        localVisited.add(childId);
        final subChildren = nodes.where((n) => n.parentId == childId).toList();
        if (subChildren.isEmpty) return 1;
        int maxSubDepth = 0;
        for (final sc in subChildren) {
          final d = getPathDepth(sc.id, localVisited);
          if (d > maxSubDepth) maxSubDepth = d;
        }
        return maxSubDepth + 1;
      }

      for (final child in children) {
        final d = getPathDepth(child.id, {id});
        if (d > maxDepth) {
          maxDepth = d;
          bestChildId = child.id;
        }
      }

      return find(bestChildId);
    }

    return find(rootId);
  }
}
