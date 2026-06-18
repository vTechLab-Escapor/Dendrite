import json, requests
HOST="https://xiaohuanxiong.com"
TOK=open(r"C:/Users/49454/Desktop/办公小浣熊token.txt").read().strip()
H={"Authorization":"Bearer "+TOK,"Content-Type":"application/json"}

# Prompt derived FROM submission/Dendrite-Branch-Map.md — the real knowledge tree
# produced by using Dendrite to review Dendrite's own Flutter repo. The deck is
# organized "according to the branch map": each branch becomes a case-study page.
prompt=(
"主题：Dendrite——AI 原生的非线性知识空间，用「可分支对话树 + 一键生成 PPT」解决大型代码仓库评审中的知识沉淀难题。"
"本 PPT 须依据一份真实知识树来组织：我们用 Dendrite 评审 Dendrite 自身的 Flutter 仓库，产出 16 节点 / 7 分支 / 6 条收藏结论。\n"
"请直接生成、无需再追问页数或任何补充信息。结构（固定 13 页，科技+商务风，每页配清晰示意图或图标；不要装饰性色条、不要标题下划线）：\n"
"1 封面：产品定位与一句话价值主张。\n"
"2 场景与痛点：开发团队评审/分析大型代码仓库（新项目评审、技术债评估、迁移前准备），成员用聊天工具与 IDE 插件实时记录想法、摘录代码、标注风险点；但思路并行、难以线性总结，评审后难以沉淀为可追溯、可复现的知识。\n"
"3 解决方案：把讨论文本、代码、注释整合成可追溯的树状对话；在任意一句话上开新分支，保留主线、并行记录思路。配「对话树/思维导图」结构示意图。\n"
"4 七大关键能力（逐项配图）：非线性分支；本地安全存储（对话/收藏/附件存本地 SQLite，API Key 仅存系统密钥库）；多模型支持（OpenAI / Anthropic / Gemini 无缝切换）；流式响应（SSE 逐 token 实时呈现）；全局搜索与收藏；PPT 生成接口（把完整对话树序列化为 JSON 交给 raccoon-ppt-skill 输出结构化 *.pptx）；一键下载/分享（邮件、企业 IM 等）。\n"
"5-10 实战案例（用 Dendrite 评审自身仓库得到的知识树，每条分支单独成页，按『选中上下文 → 提问 → 结论』呈现）：\n"
"① 多供应商 SSE 引擎：AgentEngine 用 ApiDialect 区分 openai/anthropic/gemini，按方言分派 endpoint/headers/body/delta；dart:io 原生 SSE 绕开 Android 缓冲，实现逐 token 流式。\n"
"② 安全风险：Gemini 把 key 放进 URL query，可能被代理或日志留存（中危，建议改请求头携带）。\n"
"③ 树与上下文：单张 Messages 表以 parentId 构成树，WITH RECURSIVE CTE 一次取祖先链；模型上下文只取『当前节点到根』，控制 token、分支互不污染。\n"
"④ 技术债：搜索的注释写着 FTS5，实际是 content LIKE '%q%'，无索引、无排序，规模化会退化，建议补建 FTS5。\n"
"⑤ 密钥存储：flutter_secure_storage（iOS Keychain / Android Keystore），旧版明文密钥自动迁移并从文件剔除。\n"
"⑥ 一键成稿：buildTreeMarkdown 把整棵树序列化成嵌套标题、剥离 <think>、标注 ⭐ 收藏结论，交给 raccoon-ppt-skill。\n"
"11 成果与价值：评审知识 100% 可追溯/可复现，整理汇报时间大幅下降，零服务器/订阅成本。\n"
"12 结尾：开源地址 github.com/vTechLab-Escapor/Dendrite，行动号召。\n"
"硬约束：多模型仅限 OpenAI / Anthropic / Gemini，不要出现 Llama/Qwen/GPT-4 等具体型号；不要编造安装命令、邮箱或域名；项目为 Flutter（Android/iOS/Web）。"
)
assert len(prompt)<=2000, f"prompt too long: {len(prompt)} chars"
print("prompt length:",len(prompt))

body={"prompt":prompt,"role":"开发者","scene":"工作汇报","audience":"公司内部（上级/同事/下属）"}
s=requests.Session(); s.trust_env=False
r=s.post(f"{HOST}/api/open/office/v2/ppt_jobs",headers=H,json=body,timeout=240)
print("HTTP",r.status_code)
print(r.text[:600])
try:
    d=r.json()["data"]; job=d.get("job_id")
    if job:
        json.dump({"job_id":job},open(r"D:/ProgramData/Dendrite/raccoon_skills/ppt_state.json","w"))
        print("SAVED job_id:",job,"status:",d.get("status"))
except Exception as e:
    print("parse err",e)
