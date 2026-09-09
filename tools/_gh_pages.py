# -*- coding: utf-8 -*-
"""临时脚本：开启 GitHub Pages（GitHub Actions 源）+ 查看 Actions 运行状态"""
import os, json, urllib.request, urllib.error

TOKEN = os.environ.get('GH_TOKEN', '')
USER = '13080661125'
REPO = 'work-memo-alarm'
API = 'https://api.github.com'

def req(method, path, data=None, timeout=60):
    url = API + path
    body = json.dumps(data).encode('utf-8') if data is not None else None
    r = urllib.request.Request(url, data=body, method=method)
    r.add_header('Authorization', 'token ' + TOKEN)
    r.add_header('Accept', 'application/vnd.github+json')
    r.add_header('Content-Type', 'application/json')
    r.add_header('User-Agent', 'work-memo-setup')
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8') or '{}')
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8', 'ignore')
        try:
            return e.code, json.loads(raw or '{}')
        except Exception:
            return e.code, {'message': raw[:400]}
    except Exception as e:
        return 0, {'message': str(e)}

# 1. 开启 Pages（GitHub Actions 作为源）
code, pg = req('POST', '/repos/%s/%s/pages' % (USER, REPO), {'build_type': 'workflow'})
print('Pages 设置 HTTP', code)
if code in (200, 201):
    print('  Pages 网址:', pg.get('html_url'))
    print('  构建类型:', (pg.get('build_type') or ''))
else:
    print('  message:', pg.get('message'))

# 2. 查看 Actions 运行状态
code, runs = req('GET', '/repos/%s/%s/actions/runs?per_page=10' % (USER, REPO))
if code == 200:
    print('\n最近的工作流运行：')
    for r in runs.get('workflow_runs', []):
        print('  -', r.get('name'), '|', r.get('status'), '|', r.get('conclusion'), '|', r.get('html_url'))
else:
    print('查询 Actions 失败', code, runs.get('message'))
