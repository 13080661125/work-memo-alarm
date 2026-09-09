# -*- coding: utf-8 -*-
"""临时脚本：用 GitHub API 创建仓库 + 开启 Pages（token 从环境变量读取，不落盘）"""
import os, json, urllib.request, urllib.error

TOKEN = os.environ.get('GH_TOKEN', '')
USER = '1308006612S'
REPO = 'work-memo-alarm'
API = 'https://api.github.com'

def req(method, path, data=None):
    url = API + path
    body = json.dumps(data).encode('utf-8') if data is not None else None
    r = urllib.request.Request(url, data=body, method=method)
    r.add_header('Authorization', 'token ' + TOKEN)
    r.add_header('Accept', 'application/vnd.github+json')
    r.add_header('Content-Type', 'application/json')
    r.add_header('User-Agent', 'work-memo-setup')
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8') or '{}')
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8', 'ignore')
        try:
            return e.code, json.loads(raw or '{}')
        except Exception:
            return e.code, {'message': raw[:300]}

# 1. 检查仓库是否已存在
code, info = req('GET', '/repos/%s/%s' % (USER, REPO))
if code == 200:
    print('仓库已存在:', info.get('html_url'))
else:
    code, info = req('POST', '/user/repos', {
        'name': REPO,
        'description': '工作备忘录 + 闹钟提醒（Flutter 跨平台，含浏览器版）',
        'private': False,
        'auto_init': False,
    })
    if code in (200, 201):
        print('仓库创建成功:', info.get('html_url'))
    else:
        print('创建失败 HTTP', code, info.get('message'))
        raise SystemExit(1)

print('clone_url:', info.get('clone_url'))
print('default_branch:', info.get('default_branch'))
