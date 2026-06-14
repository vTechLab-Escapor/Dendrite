import os, json, requests
HOST="https://xiaohuanxiong.com"
TOK=open(r"C:/Users/49454/Desktop/办公小浣熊token.txt").read().strip()
H={"Authorization":"Bearer "+TOK,"Content-Type":"application/json"}
prompt=("生成一份参赛演示 PPT，主题是开源项目 Dendrite —— 一个 AI 原生的非线性知识空间"
"（用 Flutter 开发，支持 Android / iOS / Web）。请按以下结构展开：\n"
"1) 场景与痛点：线性 AI 对话在深度调研、整理汇报时，主线被长滚动条冲走、想并行对比只能开一堆窗口反复复制粘贴上下文、聊完即散思路无法沉淀。\n"
"2) 解决方案：每一段对话都是一棵可分支的知识树——在任意回答里选中一句话即可开一条新分支深入探讨，选中内容自动作为该分支上下文，主线不受影响；用思维导图俯瞰整棵树并一键跳回；收藏+全局搜索+一键导出 Markdown 大纲。\n"
"3) 技术实现：树形数据结构；模型上下文只取当前节点到根的祖先链（一条 WITH RECURSIVE SQL）；统一多供应商流式引擎，抹平 NVIDIA / OpenAI / Anthropic / Gemini 协议差异；本地优先（SQLite + 设备安全区存密钥）。\n"
"4) 成果与价值：整理大纲时间预计减少约 60%，关键结论 100% 可检索，零服务器/订阅成本；可复用于任意调研与汇报场景。\n"
"风格：科技 + 商务，配图建议清晰，10-14 页。")
body={"prompt":prompt,"role":"开发者","scene":"项目路演","audience":"专业人士"}
s=requests.Session(); s.trust_env=False
r=s.post(f"{HOST}/api/open/office/v2/ppt_jobs",headers=H,json=body,timeout=120)
print("HTTP",r.status_code)
print(r.text[:600])
try:
    d=r.json()["data"]; job=d.get("job_id")
    if job:
        json.dump({"job_id":job},open(r"D:/ProgramData/Dendrite/raccoon_skills/ppt_state.json","w"))
        print("SAVED job_id:",job,"status:",d.get("status"))
except Exception as e:
    print("parse err",e)
