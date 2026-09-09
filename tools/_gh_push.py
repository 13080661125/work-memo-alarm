# -*- coding: utf-8 -*-
"""临时脚本：用 GitHub Git Data API 一次性提交全部文件（本机 git 直连 github.com 不通时的备选方案）
token 从环境变量 GH_TOKEN 读取，不写入磁盘。
"""
import os, sys, json, base64, subprocess, time, urllib.request, urllib.error

TOKEN = os.environ.get('GH_TOKEN', '')
USER = '13080661125'
REPO = 'work-memo-alarm'
API = 'https://api.github.com'
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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
            return e.code, {'message': raw[:300]}
    except Exception as e:
        return 0, {'message': str(e)}

# ---------- 0. 空仓库初始化：先塞一个占位文件，否则 blob API 报 409 ----------
code, refchk = req('GET', '/repos/%s/%s/git/ref/heads/main' % (USER, REPO))
if code != 200:
    print('仓库为空，先创建初始化文件')
    code, init = req('PUT', '/repos/%s/%s/contents/.gitkeep' % (USER, REPO), {
        'message': 'init', 'content': base64.b64encode(b'').decode('ascii')
    })
    if code not in (200, 201):
        print('初始化失败', code, init.get('message'))
        raise SystemExit(1)
    print('初始化完成')

# ---------- 1. 取文件列表（-z 避免中文路径被引号转义） ----------
out = subprocess.check_output(['git', 'ls-files', '-z'], cwd=PROJ)
files = [f for f in out.decode('utf-8').split('\0') if f]
print('待提交文件数:', len(files))

# ---------- 2. 逐个创建 blob ----------
items = []
for i, rel in enumerate(files, 1):
    full = os.path.join(PROJ, rel)
    if not os.path.isfile(full):
        print('  [跳过-不存在]', rel)
        continue
    with open(full, 'rb') as fp:
        b64 = base64.b64encode(fp.read()).decode('ascii')
    code, info = 0, {}
    for attempt in range(5):          # 网络不稳，失败自动重试
        code, info = req('POST', '/repos/%s/%s/git/blobs' % (USER, REPO),
                         {'content': b64, 'encoding': 'base64'}, timeout=120)
        if code in (200, 201):
            break
        print('    重试 %s (第 %d 次): %s' % (rel, attempt + 1, str(info.get('message'))[:60]))
        time.sleep(3)
    if code not in (200, 201):
        print('  [blob 失败]', rel, code, info.get('message'))
        raise SystemExit(1)
    items.append({'path': rel.replace('\\', '/'), 'mode': '100644',
                  'type': 'blob', 'sha': info['sha']})
    if i % 15 == 0 or i == len(files):
        print('  已上传 %d/%d' % (i, len(files)))

# ---------- 3. 创建 tree（文件多时请求体较大，超时放宽到 180 秒） ----------
code, tree = req('POST', '/repos/%s/%s/git/trees' % (USER, REPO), {'tree': items}, timeout=180)
if code not in (200, 201):
    print('tree 创建失败', code, tree.get('message'))
    raise SystemExit(1)
print('tree:', tree['sha'])

# ---------- 4. 创建 commit（有历史则接在后面） ----------
parents = []
code, ref0 = req('GET', '/repos/%s/%s/git/ref/heads/main' % (USER, REPO))
if code == 200 and ref0.get('object'):
    parents = [ref0['object']['sha']]
code, cm = req('POST', '/repos/%s/%s/git/commits' % (USER, REPO), {
    'message': 'web: 应用底色换成水彩柯基草地背景图（corgi_bg.jpg），降低透明度保证可读',
    'tree': tree['sha'],
    'parents': parents,
})
if code not in (200, 201):
    print('commit 创建失败', code, cm.get('message'))
    raise SystemExit(1)
print('commit:', cm['sha'])

# ---------- 5. 指向 main 分支 ----------
code, ref = req('GET', '/repos/%s/%s/git/ref/heads/main' % (USER, REPO))
if code == 200:
    code, ref = req('PATCH', '/repos/%s/%s/git/refs/heads/main' % (USER, REPO),
                    {'sha': cm['sha'], 'force': True})
else:
    code, ref = req('POST', '/repos/%s/%s/git/refs' % (USER, REPO),
                    {'ref': 'refs/heads/main', 'sha': cm['sha']})
if code in (200, 201):
    print('推送完成 -> https://github.com/%s/%s' % (USER, REPO))
else:
    print('ref 更新失败', code, ref.get('message'))
    raise SystemExit(1)
