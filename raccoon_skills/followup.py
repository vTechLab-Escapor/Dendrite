import json, requests, sys, time
HOST="https://xiaohuanxiong.com"
TOK=open(r"C:/Users/49454/Desktop/办公小浣熊token.txt").read().strip()
H={"Authorization":"Bearer "+TOK}; HJ={**H,"Content-Type":"application/json"}
s=requests.Session(); s.trust_env=False
OUT=r"D:/ProgramData/Dendrite/submission/intro/docassets"
sid=json.load(open(r"D:/ProgramData/Dendrite/raccoon_skills/da_state.json"))["session_id"]
print("multi-turn follow-up on session",sid)
prompt=("很好。请在同一组数据上做一次调优：单独画出『Dendrite 相对线性的节省比例(%)』随分支数变化的折线图，"
        "用线性回归预测分支数为 20 时的节省比例，并在图上标注预测点。")
body={"content":prompt,"upload_file_id":[],"verbose":False}
buf=[]
with s.post(f"{HOST}/api/open/office/v2/sessions/{sid}/chat/conversations",headers=HJ,json=body,stream=True,timeout=300) as r:
    print("CHAT",r.status_code)
    for line in r.iter_lines(decode_unicode=True):
        if line and line.startswith("data:"):
            pl=line[5:].strip()
            if pl=="[DONE]": break
            try:
                o=json.loads(pl); d=(o.get("data") or {}).get("delta","")
                if d: buf.append(d); sys.stdout.write(d); sys.stdout.flush()
            except: pass
open(OUT+"/raccoon_analysis_text2.md","w",encoding="utf-8").write("".join(buf))
print("\n--- turn2 len:",sum(len(x) for x in buf))
# fetch newest artifacts
for i in range(8):
    r=s.get(f"{HOST}/api/open/office/v2/sessions/{sid}/artifacts",headers=H,timeout=60)
    arts=((r.json().get("data") or {}).get("artifacts")) or []
    print(f"poll {i}: {len(arts)} artifacts")
    if len(arts)>=2: break
    time.sleep(6)
n=0
for a in arts:
    if a.get("type")=="image" and a.get("s3_url"):
        d=s.get(a["s3_url"],timeout=120); p=f"{OUT}/raccoon_chart_turn2_{n}.png"
        open(p,"wb").write(d.content); print("saved",p,len(d.content),"<-",a.get("filename")); n+=1
print("imgs now:",n)
