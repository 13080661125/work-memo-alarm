# -*- coding: utf-8 -*-
"""临时脚本：查看 Actions 失败步骤与日志"""
import os, json, urllib.request, urllib.error, sys, zipfile, io

TOKEN = os.environ.get('GH_TOKEN', '')
USER = '13080661125'
REPO = 'work-memo-alarm'
API = 'https://api.github.com'
RUN = sys.argv[1] if len(sys.argv) > 1 else ''

def raw(method, url, data=None, headers=None, timeout=60):
    body = json.dumps(data).encode('utf-8') if data is not None else None
    r = urllib.request.Request(url, data=body, method=method)
    for k, v in (headers or {}).items():
        r.add_header(k, v)
    r.add_header('Authorization', 'token ' + TOKEN)
    r.add_header('User-Agent', 'work-memo-setup')
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return resp.status, resp.read(), dict(resp.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read(), dict(e.headers)

def api(method, path, data=None):
    st, body, _ = raw(method, API + path, data,
                      {'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json'})
    try:
        return st, json.loads(body.decode('utf-8') or '{}')
    except Exception:
        return st, {'message': body[:300].decode('utf-8', 'ignore')}

def download(url):
    st, body, _ = raw('GET', url, None, {'Accept': 'application/vnd.github+json'})
    return st, body

st, jobs = api('GET', '/repos/%s/%s/actions/runs/%s/jobs?per_page=10' % (USER, REPO, RUN))
print('DEBUG status=%s total=%s keys=%s' % (st, jobs.get('total_count'), list(jobs.keys())[:6]))
print('DEBUG body=%s' % str(jobs)[:800])
if st != 200:
    print('查询失败', st, jobs)
    raise SystemExit(1)

for job in jobs.get('jobs', []):
    print('=' * 70)
    print('JOB:', job.get('name'), '| 结论:', job.get('conclusion'))
    for s in job.get('steps', []):
        print('   [%s] %s' % (s.get('conclusion'), s.get('name')))
    if job.get('conclusion') != 'success':
        st, blob = download('/repos/%s/%s/actions/jobs/%s/logs' % (USER, REPO, job['id']))
        if st in (200, 302):
            try:
                z = zipfile.ZipFile(io.BytesIO(blob))
                for n in z.namelist():
                    txt = z.read(n).decode('utf-8', 'ignore')
                    lines = txt.splitlines()
                    print('   ---- 日志尾部 (%s) ----' % n)
                    for ln in lines[-60:]:
                        print('   |', ln)
            except Exception as e:
                print('   日志解析失败:', e, blob[:200])
        else:
            print('   日志下载失败', st)
