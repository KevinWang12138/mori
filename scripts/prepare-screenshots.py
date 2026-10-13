#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parent.parent
RECORD = ROOT / 'build/documentation-session.json'
DOMAIN = 'com.kevin.mori.documentation'


def cleanup():
    if not RECORD.exists():
        return
    record = json.loads(RECORD.read_text())
    directory = Path(record['directory'])
    pid = record['pid']
    binary = record['binary']
    command = subprocess.run(['ps', '-p', str(pid), '-o', 'command='], capture_output=True, text=True).stdout.strip()
    if command == binary:
        os.kill(pid, 15)
        for _ in range(50):
            command = subprocess.run(['ps', '-p', str(pid), '-o', 'command='], capture_output=True, text=True).stdout.strip()
            if command != binary:
                break
            time.sleep(0.1)
        else:
            raise RuntimeError('截图实例尚未退出，请保留目录并继续处理。')
    backup = directory / 'previous-preferences.plist'
    if backup.exists():
        subprocess.run(['defaults', 'import', DOMAIN, str(backup)], check=True, capture_output=True)
    else:
        subprocess.run(['defaults', 'delete', DOMAIN], capture_output=True)
    shutil.rmtree(directory)
    RECORD.unlink()
    print('截图实例与临时资料已清理。')


def prepare():
    if RECORD.exists():
        raise RuntimeError('已有截图实例，请先使用 --cleanup 清理。')
    source = ROOT / 'build/Mori.app'
    if not source.exists():
        raise RuntimeError('请先运行 scripts/build-app.sh。')
    directory = Path(tempfile.mkdtemp(prefix='mori-documentation-'))
    process = None
    preferences_changed = False
    try:
        app = directory / 'Mori Documentation.app'
        shutil.copytree(source, app)
        info = app / 'Contents/Info.plist'
        values = plistlib.loads(info.read_bytes())
        values['CFBundleIdentifier'] = DOMAIN
        values['CFBundleDisplayName'] = 'Mori Documentation'
        values['CFBundleName'] = 'Mori Documentation'
        info.write_bytes(plistlib.dumps(values))
        subprocess.run(['codesign', '--force', '--timestamp=none', '--sign', '-', str(app)], check=True, capture_output=True)
        exported = subprocess.run(['defaults', 'export', DOMAIN, '-'], capture_output=True)
        if exported.returncode == 0:
            (directory / 'previous-preferences.plist').write_bytes(exported.stdout)
        preferences = {
            'theme': 'sage', 'wallpaper': 'forest', 'fit': 'cover',
            'backgroundColor': '#E5EBE4', 'overlayColor': '#E5EBE4',
            'wallpaperOpacity': 0.9, 'blur': 0.7, 'saturation': 0.85, 'overlayOpacity': 0.08,
            'scale': 1.0, 'positionX': 0.5, 'positionY': 0.5, 'paperOpacity': 0.92, 'sidebarOpacity': 0.9,
            'font': 'editorial', 'fontSize': 18.0, 'lineHeight': 1.85, 'pageWidth': 760.0,
            'autosave': True, 'spellcheck': False, 'showLineNumbers': True, 'wordGoal': 1000, 'customCSS': ''
        }
        preferences_file = directory / 'preferences.plist'
        preferences_file.write_bytes(plistlib.dumps({'appearance': json.dumps(preferences).encode(), 'interfaceLanguage': 'en'}))
        subprocess.run(['defaults', 'import', DOMAIN, str(preferences_file)], check=True, capture_output=True)
        preferences_changed = True
        support = directory / 'Support'
        blog = directory / 'Fieldnotes'
        support.mkdir(); blog.mkdir()
        article = (ROOT / 'docs/screenshots/example-article.md').read_text()
        samples = {
            'quiet-hours.md': article,
            'field-notes.md': '# Field notes\n\nA notebook for observations, links, and the beginnings of a story.\n\n## Collected ideas\n\n- Morning light on the desk\n- A walk through the neighborhood\n- One sentence worth keeping\n',
            '写作札记.md': '# 给文字留一点时间\n\n晨光落在书桌上，一页纸等着今天的第一个想法。\n\n## 从一行文字开始\n\n把观察记下来，慢慢写成一篇自己的文章。\n\n> 写作，是把散落的想法慢慢收拢。\n\n- [x] 留一段安静的时间\n- [ ] 写下今天的第一个想法\n\n## 写成一篇博客\n\n文章和图片属于你。Mori 离线工作，背景、文字和写作节奏都可以按自己的习惯调整。\n'
        }
        documents = []
        for filename, content in samples.items():
            path = blog / filename
            path.write_text(content)
            documents.append({'id': str(uuid.uuid4()), 'path': str(path), 'content': content, 'savedContent': content,
                              'fingerprint': hashlib.sha256(content.encode()).hexdigest(), 'usesCRLF': False, 'hasBOM': False})
        (support / 'session.json').write_text(json.dumps({'documents': documents, 'activeID': documents[0]['id'], 'workspacePath': str(blog)}, ensure_ascii=False))
        environment = os.environ.copy(); environment['MORI_DOCUMENTATION_DIRECTORY'] = str(support)
        binary = str(app / 'Contents/MacOS/Mori')
        log = open(directory / 'application.log', 'wb')
        process = subprocess.Popen([binary], env=environment, stdout=log, stderr=log, start_new_session=True)
        log.close()
        RECORD.parent.mkdir(exist_ok=True)
        RECORD.write_text(json.dumps({'directory': str(directory), 'app': str(app), 'binary': binary, 'pid': process.pid}, indent=2))
        print(json.dumps({'app': str(app), 'pid': process.pid, 'documentation_record': str(RECORD)}, ensure_ascii=False))
    except Exception:
        if process is not None and process.poll() is None:
            process.terminate(); process.wait(timeout=5)
        if preferences_changed:
            backup = directory / 'previous-preferences.plist'
            if backup.exists():
                subprocess.run(['defaults', 'import', DOMAIN, str(backup)], check=True, capture_output=True)
            else:
                subprocess.run(['defaults', 'delete', DOMAIN], capture_output=True)
        shutil.rmtree(directory)
        RECORD.unlink(missing_ok=True)
        raise


if __name__ == '__main__':
    cleanup() if '--cleanup' in sys.argv else prepare()
