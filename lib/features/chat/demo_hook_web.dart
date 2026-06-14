// Web-only demo automation hook. Exposes JS globals so a Playwright/CDP driver
// can build a REAL branched conversation deterministically (synthetic text
// selection can't drive Flutter's SelectionArea on CanvasKit). Compiled only for
// the demo recording build; a no-op stub is used off the web.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dendrite/features/chat/chat_cubit.dart';

void installDemoHooks(ChatCubit cubit) {
  // __dendriteNodes() -> JSON [{id, parentId, role, content}] for the current chat.
  globalContext['__dendriteNodes'] = (() {
    final list = cubit.state.allNodesInChat
        .map((n) => {'id': n.id, 'parentId': n.parentId, 'role': n.role, 'content': n.content})
        .toList();
    return jsonEncode(list).toJS;
  }).toJS;

  // __dendriteBranch(sourceId, ctx, question) -> create a real branch off sourceId.
  globalContext['__dendriteBranch'] =
      ((JSString sourceId, JSString ctx, JSString question) {
    cubit.createBranchQuestion(sourceId.toDart, ctx.toDart, question.toDart);
  }).toJS;

  // __dendriteNewChat() -> start a clean conversation (deterministic recording).
  globalContext['__dendriteNewChat'] = (() { cubit.newChat(); }).toJS;

  // __dendriteExportMarkdown() -> the full tree serialized to Markdown, so the
  // CDP driver can save the exact artifact that gets fed into Little Raccoon.
  globalContext['__dendriteExportMarkdown'] =
      (() => cubit.buildTreeMarkdown().toJS).toJS;
}
