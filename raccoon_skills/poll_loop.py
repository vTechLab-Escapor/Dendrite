import json,requests,time,sys
HOST="https://xiaohuanxiong.com"
TOK=open(r"C:/Users/49454/Desktop/办公小浣熊token.txt").read().strip()
job=json.load(open(r"D:/ProgramData/Dendrite/raccoon_skills/ppt_state.json"))["job_id"]
out=r"D:/ProgramData/Dendrite/submission/Dendrite-Raccoon-PPT.pptx"
s=requests.Session(); s.trust_env=False
H={"Authorization":"Bearer "+TOK}
deadline=time.time()+2.5*3600
while time.time()<deadline:
    try:
        d=s.get(f"{HOST}/api/open/office/v2/ppt_jobs/{job}",headers=H,timeout=60).json().get("data",{})
    except Exception as e:
        print(time.strftime("%H:%M:%S"),"poll error",e,flush=True); time.sleep(180); continue
    st=d.get("status"); url=d.get("download_url") or ""; q=d.get("question") or ""
    print(time.strftime("%H:%M:%S"),"status:",st,flush=True)
    if st=="succeeded" and url:
        data=s.get(url,timeout=300).content
        open(out,"wb").write(data)
        print("DOWNLOADED ->",out,len(data),"bytes",flush=True); sys.exit(0)
    if st=="waiting_user_input":
        print("WAITING_USER_INPUT:",q,flush=True); sys.exit(2)
    if st in ("failed","canceled"):
        print("ENDED:",st,d.get("error_message"),flush=True); sys.exit(3)
    time.sleep(180)
print("TIMEOUT after 2.5h, still",st,flush=True); sys.exit(4)
