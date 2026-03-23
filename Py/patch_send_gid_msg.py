from pathlib import Path
import sys
import re


def patch_file(path: Path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    old_text = text

    new_lines = []
    patched = 0

    for line in text.splitlines(keepends=True):
        if "common::send_gid_msg" in line:
            # 尝试提取最后一个双引号字符串作为消息体
            m = re.search(r'"([^"]*)"\s*$', line.strip())
            if m:
                msg = m.group(1)
                new_lines.append(f'puts "{msg}"\n')
            else:
                new_lines.append("# " + line if not line.lstrip().startswith("#") else line)
            patched += 1
        else:
            new_lines.append(line)

    new_text = "".join(new_lines)

    if new_text != old_text:
        bak = path.with_suffix(path.suffix + ".bak")
        bak.write_text(old_text, encoding="utf-8", newline="")
        path.write_text(new_text, encoding="utf-8", newline="")
        print(f"[PATCHED] {path} ({patched} lines)")
    else:
        print(f"[NO_CHANGE] {path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python patch_send_gid_msg.py <file_or_dir>")
        sys.exit(1)

    target = Path(sys.argv[1])

    if not target.exists():
        print(f"[ERROR] Path not found: {target}")
        sys.exit(2)

    if target.is_file():
        patch_file(target)
    else:
        for f in target.rglob("*.tcl"):
            patch_file(f)


if __name__ == "__main__":
    main()