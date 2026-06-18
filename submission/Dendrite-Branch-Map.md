# Dendrite — 知识树导出

> **主题：** 请对 Dendrite（Flutter 代码仓库）做一次完整架构评审：分层结构、AI 引擎、数据层、状态管理与安全，并指出技术债与风险。目标是把评审结论沉淀成可追溯的知识，再一键生成给管理层的汇报 PPT。
>
> **节点数：** 16 · **分支数：** 7 · 导出时间：2026-06-18T17:59:28

## 提问

**Q：** 请对 Dendrite（Flutter 代码仓库）做一次完整架构评审：分层结构、AI 引擎、数据层、状态管理与安全，并指出技术债与风险。目标是把评审结论沉淀成可追溯的知识，再一键生成给管理层的汇报 PPT。

**A：** Dendrite 是一个 AI 原生的非线性知识空间，采用 Flutter + flutter_bloc（Cubit）分层：core/（agent 引擎、db 数据层、models、utils）与 features/（chat、map 思维导图、settings）。核心是把每段对话建模成可分支的树——消息节点通过 parentId 串成树，选中任意一句话即可在其上开分支。数据层用 Drift/SQLite 本地存储；AI 层是统一的多供应商 SSE 流式引擎；密钥存系统安全区。下面按分支深入各模块。

### 🌿 分支：「统一的多供应商 SSE 流式引擎」

> 选中上下文：统一的多供应商 SSE 流式引擎

**Q：** 这个引擎如何抹平不同厂商的协议差异？

**A：** AgentEngine.submitQueryStream 用 ApiDialect 枚举区分 openai / anthropic / gemini 三种方言：OpenAI 兼容族（NVIDIA、ModelScope、OpenAI、Grok、小米）共用一套；Anthropic 与 Gemini 各有请求体与 SSE 事件结构。_endpoint / _buildHeaders / _buildBody / _extractDelta 四个方法按方言分派——OpenAI 用 Bearer 与 choices[0].delta.content；Anthropic 用 x-api-key + anthropic-version、system 顶层字段、content_block_delta；Gemini 把 key 放进 URL query，contents 用 role=model、candidates[0].content.parts[0].text。传输层用 dart:io HttpClient 做原生 SSE，条件导入区分 native/web，绕开 Android HttpURLConnection 的缓冲，实现真正逐 token 流式。

> ⭐ 已收藏的关键结论

#### 🌿 分支：「Gemini 把 key 放进 URL query」

> 选中上下文：Gemini 把 key 放进 URL query

**Q：** 这会不会有安全隐患？

**A：** 会。密钥出现在 URL 查询串里，可能被反向代理、网关或访问日志留存。建议改用请求头携带或短期令牌，并对日志脱敏。定级：中危安全项，建议在迁移前修复。

> ⭐ 已收藏的关键结论

### 🌿 分支：「消息节点通过 parentId 串成树」

> 选中上下文：消息节点通过 parentId 串成树

**Q：** 树状对话与模型上下文具体怎么存、怎么取？

**A：** 单张 Messages 表（id、parentId 可空→构成树、chatId、role、content、associatedSelection 分支选中上下文、isBookmarked、createdAt）。取上下文用一条 WITH RECURSIVE lineage CTE 沿 parent_id 由叶到根回溯，一次查询拿到完整祖先链并按 created_at 排序。关键设计：发给模型的上下文只取『当前节点到根』的祖先链，而非整个会话——天然控制 token 成本，主线与各分支互不污染。

> ⭐ 已收藏的关键结论

#### 🌿 分支：「一次查询拿到完整祖先链」

> 选中上下文：一次查询拿到完整祖先链

**Q：** 全文检索也是这套机制吗？是真正的 FTS5 吗？

**A：** 不是。提交记录与方法注释都写着『FTS5 search』，但实际实现是 content LIKE '%query%'——没有 FTS5 虚拟表、没有倒排索引、没有相关性排序。小数据量可用，规模化后会线性退化且无法排序。这是一处名实不符的技术债，建议补建真正的 FTS5 索引并保留 LIKE 作为降级。

> ⭐ 已收藏的关键结论

### 🌿 分支：「密钥存系统安全区」

> 选中上下文：密钥存系统安全区

**Q：** API Key 到底存在哪里？

**A：** SettingsRepository 把非敏感配置（provider/baseUrl/modelName）写进应用文档目录的 JSON 文件，而 API Key 单独存入 flutter_secure_storage（iOS Keychain / Android Keystore）。旧版本若把密钥明文存在 JSON 里，load() 会自动迁移到安全区并从文件剔除。编译期密钥通过 --dart-define 注入。

> ⭐ 已收藏的关键结论

### 🌿 分支：「features/（chat、map 思维导图、settings）」

> 选中上下文：features/（chat、map 思维导图、settings）

**Q：** 评审完怎么一键变成汇报 PPT？

**A：** buildTreeMarkdown 把整棵树（不只是当前主线，而是每一条分支）序列化成『嵌套标题』的 Markdown/JSON：分支问题降级为子标题、剥离 <think> 推理、⭐ 收藏节点标注为关键结论。这份结构化大纲正是『PPT 生成接口』的输入——交给 raccoon-ppt-skill 即输出结构化 *.pptx。io/web 条件导出：Web 走浏览器下载，移动/桌面写入文档目录并弹出分享面板。

> ⭐ 已收藏的关键结论

### 🌿 分支：「features/（chat、map 思维导图」

> 选中上下文：features/（chat、map 思维导图

**Q：** 代码里有没有明显的可维护性风险？

**A：** 有三处：chat_screen.dart 约 2276 行，是承担过多职责的 god-widget，建议按区域拆分组件；_extractDelta 对解析异常静默 catch，且流式中途出错仅在尚未产出任何 token 时才抛出，可能掩盖部分失败；getChatSessions 一次性把全部消息读入内存再分组，规模化存在内存压力。

