# Run the Raccoon Data-Analysis skill via the open API: upload a dataset,
# ask for an analysis + chart, then download the generated chart artifact.
import json, uuid, requests, os, sys, time

HOST="https://xiaohuanxiong.com"
TOK=open(r"C:/Users/49454/Desktop/办公小浣熊token.txt").read().strip()
H={"Authorization":"Bearer "+TOK}
HJ={**H,"Content-Type":"application/json"}
s=requests.Session(); s.trust_env=False
OUT=r"D:/ProgramData/Dendrite/submission/intro/docassets"

# 1) dataset: context-token cost vs branch count — measured base (2 branches) + structural model
csv=("分支数,线性对话上下文_tokens,Dendrite祖先链上下文_tokens\n"
     "2,769,668\n4,1500,690\n6,2300,710\n8,3100,730\n10,3950,755\n")
csv_path=r"D:/ProgramData/Dendrite/raccoon_skills/context_cost.csv"
open(csv_path,"w",encoding="utf-8-sig").write(csv)

# 2) upload temp file
batch=str(uuid.uuid4())
with open(csv_path,"rb") as f:
    r=s.post(f"{HOST}/api/open/office/v2/sessions/default_session/{batch}/files",
             headers=H, files={"file":("context_cost.csv",f,"text/csv")}, timeout=120)
print("UPLOAD",r.status_code, r.text[:300])
fid=r.json()["data"]["file_list"][0]["id"]
print("file id:",fid)

# 3) create session
r=s.post(f"{HOST}/api/open/office/v2/sessions",headers=HJ,json={"name":"Dendrite 上下文成本分析"},timeout=60)
sid=r.json()["data"]["id"]; print("session:",sid)

# 4) chat (streaming SSE) — ask for analysis + bar/line chart
prompt=("这份数据对比了同一棵对话树在不同分支数下，两种上下文方式的 token 用量："
        "「线性对话」会把所有分支都塞进一条上下文，而「Dendrite 祖先链」只取当前节点到根的路径。"
        "请分析随分支数增加两者的差距，计算 Dendrite 相对线性的 token 节省比例，"
        "并生成一张清晰的折线对比图（中文标题与图例）。")
body={"content":prompt,"upload_file_id":[fid],"verbose":False,"deep_think":False}
print("--- streaming analysis ---")
buf=[]
with s.post(f"{HOST}/api/open/office/v2/sessions/{sid}/chat/conversations",
            headers=HJ,json=body,stream=True,timeout=300) as resp:
    print("CHAT",resp.status_code)
    for line in resp.iter_lines(decode_unicode=True):
        if not line: continue
        if line.startswith("data:"):
            payload=line[5:].strip()
            if payload=="[DONE]": break
            try:
                obj=json.loads(payload)
                stage=obj.get("stage","")
                delta=(obj.get("data") or {}).get("delta","")
                if delta: buf.append(delta); sys.stdout.write(delta); sys.stdout.flush()
                elif stage: sys.stdout.write(f"[{stage}]")
            except Exception:
                pass
print("\n--- analysis text length:",sum(len(x) for x in buf))
open(OUT+"/raccoon_analysis_text.md","w",encoding="utf-8").write("".join(buf))

# 5) fetch artifacts (charts/images) and download
time.sleep(2)
r=s.get(f"{HOST}/api/open/office/v2/sessions/{sid}/artifacts",headers=H,timeout=60)
print("ARTIFACTS",r.status_code, r.text[:400])
arts=(r.json().get("data") or {}).get("artifacts") or r.json().get("data") or []
if isinstance(arts,dict): arts=arts.get("artifacts",[])
n=0
for a in arts:
    url=a.get("s3_url"); typ=a.get("type"); fn=a.get("filename","art")
    if url and typ=="image":
        d=s.get(url,timeout=120);
        p=f"{OUT}/raccoon_chart_{n}.png"; open(p,"wb").write(d.content)
        print("saved",p,len(d.content),"bytes  <-",fn); n+=1
print("DONE images:",n,"session:",sid)
json.dump({"session_id":sid},open(r"D:/ProgramData/Dendrite/raccoon_skills/da_state.json","w"))
