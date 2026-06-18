# Builds a real Dendrite branch-map (conversation tree) from an AI-driven code
# review of Dendrite's own Flutter repo, then emits:
#   1. submission/Dendrite-Branch-Map.json  — Dendrite export format (importable)
#   2. submission/Dendrite-Branch-Map.md     — buildTreeMarkdown() output: the
#      exact structured outline the in-app "PPT generation interface" feeds to
#      raccoon-ppt-skill.
import json, re, os
from datetime import datetime

CHAT = "dendrite_selfreview"
def U(i, parent, content, sel=None):
    return {"id": i, "parentId": parent, "chatId": CHAT, "role": "user",
            "content": content, "associatedSelection": sel, "isBookmarked": False}
def A(i, parent, content, mark=False):
    return {"id": i, "parentId": parent, "chatId": CHAT, "role": "assistant",
            "content": content, "associatedSelection": None, "isBookmarked": mark}

nodes = [
 U("n1", None,
   "请对 Dendrite（Flutter 代码仓库）做一次完整架构评审：分层结构、AI 引擎、数据层、状态管理与安全，"
   "并指出技术债与风险。目标是把评审结论沉淀成可追溯的知识，再一键生成给管理层的汇报 PPT。"),
 A("n2", "n1",
   "<think>先俯瞰仓库再分模块下钻。</think>\n"
   "Dendrite 是一个 AI 原生的非线性知识空间，采用 Flutter + flutter_bloc（Cubit）分层：core/（agent 引擎、"
   "db 数据层、models、utils）与 features/（chat、map 思维导图、settings）。核心是把每段对话建模成可分支的树——"
   "消息节点通过 parentId 串成树，选中任意一句话即可在其上开分支。数据层用 Drift/SQLite 本地存储；AI 层是"
   "统一的多供应商 SSE 流式引擎；密钥存系统安全区。下面按分支深入各模块。"),

 U("n3", "n2", "这个引擎如何抹平不同厂商的协议差异？", sel="统一的多供应商 SSE 流式引擎"),
 A("n4", "n3",
   "AgentEngine.submitQueryStream 用 ApiDialect 枚举区分 openai / anthropic / gemini 三种方言：OpenAI 兼容族"
   "（NVIDIA、ModelScope、OpenAI、Grok、小米）共用一套；Anthropic 与 Gemini 各有请求体与 SSE 事件结构。"
   "_endpoint / _buildHeaders / _buildBody / _extractDelta 四个方法按方言分派——OpenAI 用 Bearer 与 "
   "choices[0].delta.content；Anthropic 用 x-api-key + anthropic-version、system 顶层字段、content_block_delta；"
   "Gemini 把 key 放进 URL query，contents 用 role=model、candidates[0].content.parts[0].text。传输层用 "
   "dart:io HttpClient 做原生 SSE，条件导入区分 native/web，绕开 Android HttpURLConnection 的缓冲，实现真正逐 token 流式。",
   mark=True),
 U("n5", "n4", "这会不会有安全隐患？", sel="Gemini 把 key 放进 URL query"),
 A("n6", "n5",
   "会。密钥出现在 URL 查询串里，可能被反向代理、网关或访问日志留存。建议改用请求头携带或短期令牌，并对日志脱敏。"
   "定级：中危安全项，建议在迁移前修复。", mark=True),

 U("n7", "n2", "树状对话与模型上下文具体怎么存、怎么取？", sel="消息节点通过 parentId 串成树"),
 A("n8", "n7",
   "单张 Messages 表（id、parentId 可空→构成树、chatId、role、content、associatedSelection 分支选中上下文、"
   "isBookmarked、createdAt）。取上下文用一条 WITH RECURSIVE lineage CTE 沿 parent_id 由叶到根回溯，一次查询"
   "拿到完整祖先链并按 created_at 排序。关键设计：发给模型的上下文只取『当前节点到根』的祖先链，而非整个会话——"
   "天然控制 token 成本，主线与各分支互不污染。", mark=True),
 U("n9", "n8", "全文检索也是这套机制吗？是真正的 FTS5 吗？", sel="一次查询拿到完整祖先链"),
 A("n10", "n9",
   "不是。提交记录与方法注释都写着『FTS5 search』，但实际实现是 content LIKE '%query%'——没有 FTS5 虚拟表、"
   "没有倒排索引、没有相关性排序。小数据量可用，规模化后会线性退化且无法排序。这是一处名实不符的技术债，"
   "建议补建真正的 FTS5 索引并保留 LIKE 作为降级。", mark=True),

 U("n11", "n2", "API Key 到底存在哪里？", sel="密钥存系统安全区"),
 A("n12", "n11",
   "SettingsRepository 把非敏感配置（provider/baseUrl/modelName）写进应用文档目录的 JSON 文件，而 API Key 单独"
   "存入 flutter_secure_storage（iOS Keychain / Android Keystore）。旧版本若把密钥明文存在 JSON 里，load() 会"
   "自动迁移到安全区并从文件剔除。编译期密钥通过 --dart-define 注入。", mark=True),

 U("n13", "n2", "评审完怎么一键变成汇报 PPT？", sel="features/（chat、map 思维导图、settings）"),
 A("n14", "n13",
   "buildTreeMarkdown 把整棵树（不只是当前主线，而是每一条分支）序列化成『嵌套标题』的 Markdown/JSON：分支问题"
   "降级为子标题、剥离 <think> 推理、⭐ 收藏节点标注为关键结论。这份结构化大纲正是『PPT 生成接口』的输入——"
   "交给 raccoon-ppt-skill 即输出结构化 *.pptx。io/web 条件导出：Web 走浏览器下载，移动/桌面写入文档目录并弹出分享面板。",
   mark=True),

 U("n15", "n2", "代码里有没有明显的可维护性风险？", sel="features/（chat、map 思维导图"),
 A("n16", "n15",
   "有三处：chat_screen.dart 约 2276 行，是承担过多职责的 god-widget，建议按区域拆分组件；_extractDelta 对解析"
   "异常静默 catch，且流式中途出错仅在尚未产出任何 token 时才抛出，可能掩盖部分失败；getChatSessions 一次性把"
   "全部消息读入内存再分组，规模化存在内存压力。"),
]

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "submission"))
json_path = os.path.join(OUT, "Dendrite-Branch-Map.json")
with open(json_path, "w", encoding="utf-8") as f:
    json.dump([{k: n[k] for k in
                ("id","parentId","chatId","role","content","associatedSelection","isBookmarked")}
               for n in nodes], f, ensure_ascii=False, indent=2)

# Replicate ChatCubit.buildTreeMarkdown() exactly (Dart -> Python).
children = {}
root = None
for n in nodes:
    if n["parentId"] is None:
        root = root or n
    else:
        children.setdefault(n["parentId"], []).append(n)
root = root or nodes[0]
clean = lambda s: re.sub(r"<think>[\s\S]*?</think>", "", s).strip()
oneline = lambda s: re.sub(r"\s+", " ", s).strip()
first_user = next((n for n in nodes if n["role"] == "user"), root)
branch_count = sum(1 for n in nodes if n["associatedSelection"] is not None)
sb = []
sb.append("# Dendrite — 知识树导出\n")
sb.append(f"> **主题：** {oneline(first_user['content'])}\n>")
sb.append(f"> **节点数：** {len(nodes)} · **分支数：** {branch_count} · "
          f"导出时间：{datetime.now().isoformat()[:19]}\n")
def walk(node, depth):
    if node["role"] == "user":
        is_branch = node["associatedSelection"] is not None
        hashes = "#" * max(2, min(6, depth + 2))
        if is_branch:
            sb.append(f"{hashes} 🌿 分支：「{oneline(node['associatedSelection'])}」\n")
            sb.append(f"> 选中上下文：{oneline(node['associatedSelection'])}\n")
        else:
            sb.append(f"{hashes} 提问\n")
        sb.append(f"**Q：** {clean(node['content'])}\n")
    else:
        sb.append(f"**A：** {clean(node['content'])}\n")
        if node["isBookmarked"]:
            sb.append("> ⭐ 已收藏的关键结论\n")
    for ch in children.get(node["id"], []):
        deeper = ch["role"] == "user" and ch["associatedSelection"] is not None
        walk(ch, depth + 1 if deeper else depth)
walk(root, 0)
md = "\n".join(sb) + "\n"
md_path = os.path.join(OUT, "Dendrite-Branch-Map.md")
open(md_path, "w", encoding="utf-8").write(md)

print("nodes:", len(nodes), "| branches:", branch_count,
      "| bookmarks:", sum(1 for n in nodes if n["isBookmarked"]))
print("wrote:", json_path)
print("wrote:", md_path, f"({len(md)} chars)")
