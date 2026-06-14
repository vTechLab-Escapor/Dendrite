import json, requests, time, re
HOST="https://xiaohuanxiong.com"
TOK=open(r"C:/Users/49454/Desktop/办公小浣熊token.txt").read().strip()
H={"Authorization":"Bearer "+TOK}
s=requests.Session(); s.trust_env=False
OUT=r"D:/ProgramData/Dendrite/submission/intro/docassets"
sid=json.load(open(r"D:/ProgramData/Dendrite/raccoon_skills/da_state.json"))["session_id"]
print("session",sid)

# 1) poll artifacts
arts=[]
for i in range(8):
    r=s.get(f"{HOST}/api/open/office/v2/sessions/{sid}/artifacts",headers=H,timeout=60)
    data=r.json().get("data") or {}
    arts=data.get("artifacts") if isinstance(data,dict) else data
    arts=arts or []
    print(f"poll {i}: {len(arts)} artifacts", r.text[:160])
    if arts: break
    time.sleep(6)

n=0
for a in arts:
    url=a.get("s3_url"); typ=a.get("type"); fn=a.get("filename","art")
    if url:
        d=s.get(url,timeout=120)
        ext=".png" if typ=="image" else ("."+fn.split(".")[-1] if "." in fn else ".bin")
        p=f"{OUT}/raccoon_{('chart' if typ=='image' else 'file')}_{n}{ext}"
        open(p,"wb").write(d.content); print("saved",p,len(d.content),"<-",fn); n+=1

# 2) fallback: pull chart by sandbox file_path from the analysis text
if n==0:
    txt=open(OUT+"/raccoon_analysis_text.md",encoding="utf-8").read()
    paths=re.findall(r"sandbox:(/mnt/data/[^\)\]\s]+\.(?:png|jpg|jpeg|xlsx))",txt)
    print("sandbox paths found:",paths)
    for i,fp in enumerate(dict.fromkeys(paths)):
        r=s.get(f"{HOST}/api/open/office/v2/sessions/{sid}/files",headers=H,params={"file_path":fp},timeout=120)
        print("download",fp,r.status_code,len(r.content),"bytes")
        if r.status_code==200 and len(r.content)>500:
            ext="."+fp.split(".")[-1]
            p=f"{OUT}/raccoon_chart_{i}{ext}"; open(p,"wb").write(r.content); print("saved",p); n+=1
print("TOTAL downloaded:",n)
