import 'package:flutter_test/flutter_test.dart';
import 'package:dendrite/core/db/database.dart';
import 'package:dendrite/features/chat/chat_tree.dart';

Message _node(String id, {String? parentId, String? selection}) {
  return Message(
    id: id,
    parentId: parentId,
    chatId: 'chat-1',
    role: 'user',
    content: id,
    associatedSelection: selection,
    isBookmarked: false,
    createdAt: DateTime(2024),
  );
}

void main() {
  group('ChatTree.resolveActiveLeaf', () {
    test('returns the explicit active node when provided', () {
      final nodes = [_node('a'), _node('b', parentId: 'a')];
      expect(ChatTree.resolveActiveLeaf(nodes, 'a'), 'a');
    });

    test('returns null for an empty list with no active node', () {
      expect(ChatTree.resolveActiveLeaf([], null), isNull);
    });

    test('picks the most recent main-trunk leaf, skipping branches', () {
      final nodes = [
        _node('root'),
        _node('reply', parentId: 'root'),
        // A branch off "reply" and its child — should be skipped.
        _node('branch', parentId: 'reply', selection: 'some text'),
        _node('branch-reply', parentId: 'branch'),
      ];
      expect(ChatTree.resolveActiveLeaf(nodes, null), 'reply');
    });

    test('falls back to the first node when no clean trunk leaf exists', () {
      final nodes = [
        _node('root', selection: 'sel'),
        _node('child', parentId: 'root'),
      ];
      // 'child' has a branched ancestor; 'root' itself is a branch -> fallback.
      expect(ChatTree.resolveActiveLeaf(nodes, null), 'root');
    });
  });

  group('ChatTree.deepestDescendant', () {
    test('returns the root when it has no children', () {
      expect(ChatTree.deepestDescendant('a', [_node('a')]), 'a');
    });

    test('follows the longest path among multiple branches', () {
      final nodes = [
        _node('root'),
        _node('short', parentId: 'root'),
        _node('long1', parentId: 'root'),
        _node('long2', parentId: 'long1'),
        _node('long3', parentId: 'long2'),
      ];
      expect(ChatTree.deepestDescendant('root', nodes), 'long3');
    });
  });
}
