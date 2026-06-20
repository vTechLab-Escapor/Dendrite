// Web-only demo automation hook. Exposes JS globals so a Playwright/CDP driver
// can build a REAL branched conversation deterministically (synthetic text
// selection can't drive Flutter's SelectionArea on CanvasKit). Compiled only for
// the demo recording build; a no-op stub is used off the web.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dendrite/features/chat/chat_cubit.dart';

void installDemoHooks(
  ChatCubit cubit, {
  void Function(bool)? setMindMap,
  void Function(bool)? setDark,
  void Function()? triggerExport,
}) {
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

  // __dendriteAsk(content) -> send the ROOT question without the composer/send
  // button (whose coords shift with UI redesigns). Mirrors createBranchQuestion
  // for the trunk, so the whole tree can be built hook-only & deterministically.
  globalContext['__dendriteAsk'] = ((JSString content) {
    cubit.sendMessage(content.toDart);
  }).toJS;

  // __dendriteExportMarkdown() -> the full tree serialized to Markdown, so the
  // CDP driver can save the exact artifact that gets fed into Little Raccoon.
  globalContext['__dendriteExportMarkdown'] =
      (() => cubit.buildTreeMarkdown().toJS).toJS;

  // __dendriteBookmark(nodeId) -> toggle the gold bookmark on a node by id, so the
  // driver can stage shot 4's "收藏成金色" moment deterministically.
  globalContext['__dendriteBookmark'] = ((JSString nodeId) {
    final id = nodeId.toDart;
    for (final n in cubit.state.allNodesInChat) {
      if (n.id == id) {
        cubit.toggleBookmark(n);
        break;
      }
    }
  }).toJS;

  // View-mode toggles are widget setState (not cubit) AND the app-bar icons move
  // with UI redesigns, so synthetic clicks miss. Drive them via the State here.
  // __dendriteSetMap(true|false) -> show the mind-map / return to chat.
  if (setMindMap != null) {
    globalContext['__dendriteSetMap'] = ((JSBoolean on) => setMindMap(on.toDart)).toJS;
  }
  // __dendriteSetDark(true|false) -> toggle dark mode.
  if (setDark != null) {
    globalContext['__dendriteSetDark'] = ((JSBoolean on) => setDark(on.toDart)).toJS;
  }
  // __dendriteExport() -> run the real export action (on-screen toast + download).
  if (triggerExport != null) {
    globalContext['__dendriteExport'] = (() => triggerExport()).toJS;
  }
}
