#!/usr/bin/env python3
import datetime
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile

version, sha, artifact_path, repository_path = sys.argv[1:]
repository = "KevinWang12138/mori"
artifacts = pathlib.Path(artifact_path)
root = pathlib.Path(repository_path)


def github(endpoint):
    result = subprocess.run(["gh", "api", endpoint], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


release = github(f"repos/{repository}/releases/tags/v{version}")
assert release["tag_name"] == f"v{version}" and not release["draft"], "发布状态不正确"
reference = github(f"repos/{repository}/git/ref/tags/v{version}")["object"]
for _ in range(4):
    if reference["type"] == "commit":
        break
    reference = github(f"repos/{repository}/git/tags/{reference['sha']}")["object"]
assert reference["sha"] == sha, "发布标签与精确 SHA 不一致"

expected = [f"Mori-{version}-universal.zip", f"Mori-{version}-universal.dmg", "SHA256SUMS.txt"]
verified = []
for name in expected:
    local = artifacts / name
    asset = next(item for item in release["assets"] if item["name"] == name)
    digest = hashlib.sha256(local.read_bytes()).hexdigest()
    assert asset["state"] == "uploaded" and asset["size"] == local.stat().st_size, "上传产物大小或状态不一致"
    if asset.get("digest"):
        assert asset["digest"] == "sha256:" + digest, "上传产物 SHA256 不一致"
    else:
        with tempfile.TemporaryDirectory(prefix="mori-verify-") as temporary:
            subprocess.run(["gh", "release", "download", f"v{version}", "--repo", repository, "--pattern", name, "--dir", temporary], check=True)
            assert hashlib.sha256((pathlib.Path(temporary) / name).read_bytes()).hexdigest() == digest, "下载产物 SHA256 不一致"
    verified.append({"name": name, "size": asset["size"], "sha256": digest, "url": asset["browser_download_url"]})

manifest = {
    "repository": "https://github.com/" + repository,
    "sha": sha,
    "production_targets": ["GitHub Releases macOS universal application"],
    "version": version,
    "release_url": release["html_url"],
    "build_result": "success",
    "deployment_result": "success",
    "verification": {"tag_commit": "matched", "assets": "size and sha256 matched", "architectures": ["arm64", "x86_64"], "code_signing": "ad-hoc unless MORI_SIGN_IDENTITY was configured"},
    "assets": verified,
    "verified_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
}
(root / "build").mkdir(exist_ok=True)
(root / "build" / "release-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
registry = pathlib.Path.home() / ".codex" / "deployments"
registry.mkdir(parents=True, exist_ok=True)
pending = registry / "mori.json.new"
pending.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
pending.replace(registry / "mori.json")
print(f"已核对 v{version} 标签、完整 SHA 和 3 个发布文件的大小及 SHA256。")
