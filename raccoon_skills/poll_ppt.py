# Poll the submitted Raccoon PPT job; when done, download the .pptx into submission/.
import json, requests, os
HOST="https://xiaohuanxiong.com"
TOK=open(r"C:/Users/49454/Desktop/办公小浣熊token.txt").read().strip()
s=requests.Session(); s.trust_env=False
job=json.load(open(r"D:/ProgramData/Dendrite/raccoon_skills/ppt_state.json"))["job_id"]
r=s.get(f"{HOST}/api/open/office/v2/ppt_jobs/{job}",headers={"Authorization":"Bearer "+TOK},timeout=60)
d=r.json().get("data",{})
st=d.get("status"); url=d.get("download_url") or ""; q=d.get("question") or ""
print("job",job,"status:",st)
if q: print("Raccoon is asking:",q)
if st=="succeeded" and url:
    out=r"D:/ProgramData/Dendrite/submission/Dendrite-Raccoon-PPT.pptx"
    data=s.get(url,timeout=300).content
    open(out,"wb").write(data)
    print("DOWNLOADED ->",out,len(data),"bytes")
elif st in ("queued","running"):
    print("still generating; re-run this script in a while. (PPT 通常需 30 分钟~2 小时)")
elif st in ("failed","canceled"):
    print("job ended:",d.get("error_message"))
