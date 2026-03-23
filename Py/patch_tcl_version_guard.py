from __future__ import annotations

from pathlib import Path
import re
import sys


def count_braces_for_tcl(line: str) -> int:
    """
    对一行 Tcl 做一个简化的花括号计数：
    - 先去掉行首注释符 '#'
    - 忽略简单的字符串状态
    这里不追求 Tcl 完整语法，只服务于版本检查块定位。
    """
    s = line.lstrip()
    if s.startswith("#"):
        s = s[1:].lstrip()

    brace_delta = 0
    in_string = False
    escape = False

    for ch in s:
        if escape:
            escape = False
            continue

        if ch == "\\":
            escape = True
            continue

        if ch == '"':
            in_string = not in_string
            continue

        if in_string:
            continue

        if ch == "{":
            brace_delta += 1
        elif ch == "}":
            brace_delta -= 1

    return brace_delta


def is_version_guard_start(line: str) -> bool:
    s = line.lstrip()
    if s.startswith("#"):
        s = s[1:].lstrip()
    return s.startswith("set scripts_vivado_version ")


def is_if_version_guard_line(line: str) -> bool:
    s = line.lstrip()
    if s.startswith("#"):
        s = s[1:].lstrip()
    return (
        s.startswith("if ")
        and "scripts_vivado_version" in s
        and "current_vivado_version" in s
    )


def comment_line(line: str) -> str:
    if line.strip() == "":
        return line
    if line.lstrip().startswith("#"):
        return line
    return "# " + line


def patch_version_guard_block(text: str) -> tuple[str, str]:
    """
    修复或注释 Vivado write_ip_tcl 导出的版本检查块。
    能处理三种状态：
    1. 完全未注释
    2. 半注释（你截图这种）
    3. 已完整注释

    返回:
        (new_text, status)
        status in {"patched", "already_patched", "not_found"}
    """
    lines = text.splitlines(keepends=True)

    start_idx = None
    for i, line in enumerate(lines):
        if is_version_guard_start(line):
            start_idx = i
            break

    if start_idx is None:
        return text, "not_found"

    # 从 start_idx 开始寻找 if 行
    if_idx = None
    for i in range(start_idx, min(start_idx + 20, len(lines))):
        if is_if_version_guard_line(lines[i]):
            if_idx = i
            break

    if if_idx is None:
        # 至少把连续相关头部几行先注释掉
        new_lines = lines[:]
        changed = False
        for i in range(start_idx, min(start_idx + 5, len(lines))):
            if any(key in lines[i] for key in ["scripts_vivado_version", "current_vivado_version", "IPS_TCL-100", "return 1"]):
                new_line = comment_line(lines[i])
                if new_line != lines[i]:
                    new_lines[i] = new_line
                    changed = True
        return "".join(new_lines), ("patched" if changed else "already_patched")

    # 从 if 行开始做花括号配对，找到块结束
    brace_depth = 0
    end_idx = None
    for i in range(if_idx, len(lines)):
        brace_depth += count_braces_for_tcl(lines[i])
        if i == if_idx:
            # if 行通常会把 brace_depth 拉到 >= 1
            pass
        if i > if_idx and brace_depth <= 0:
            end_idx = i
            break

    # 如果没找到结束，就保守处理后面若干行
    if end_idx is None:
        end_idx = min(if_idx + 10, len(lines) - 1)

    patch_from = start_idx
    patch_to = end_idx

    new_lines = lines[:]
    changed = False

    for i in range(patch_from, patch_to + 1):
        new_line = comment_line(new_lines[i])
        if new_line != new_lines[i]:
            new_lines[i] = new_line
            changed = True

    # 判断是否本来就已经完整注释
    if not changed:
        return "".join(new_lines), "already_patched"

    return "".join(new_lines), "patched"


def patch_one_file(tcl_path: Path, backup: bool = True) -> str:
    raw = tcl_path.read_text(encoding="utf-8", errors="ignore")
    new_text, status = patch_version_guard_block(raw)

    if status == "patched":
        if backup:
            bak_path = tcl_path.with_suffix(tcl_path.suffix + ".bak")
            bak_path.write_text(raw, encoding="utf-8", newline="")
        tcl_path.write_text(new_text, encoding="utf-8", newline="")
    return status


def patch_directory(root: Path, recursive: bool = True) -> None:
    files = sorted(root.rglob("*.tcl")) if recursive else sorted(root.glob("*.tcl"))

    if not files:
        print(f"[INFO] 未找到 .tcl 文件: {root}")
        return

    total = patched = already = not_found = failed = 0

    for f in files:
        total += 1
        try:
            status = patch_one_file(f, backup=True)
            if status == "patched":
                patched += 1
                print(f"[PATCHED]      {f}")
            elif status == "already_patched":
                already += 1
                print(f"[ALREADY]      {f}")
            else:
                not_found += 1
                print(f"[NO_GUARD]     {f}")
        except Exception as e:
            failed += 1
            print(f"[FAILED]       {f} -> {e}")

    print("\n===== Summary =====")
    print(f"Total          : {total}")
    print(f"Patched        : {patched}")
    print(f"Already Patched: {already}")
    print(f"Not Found      : {not_found}")
    print(f"Failed         : {failed}")


def main() -> None:
    if len(sys.argv) < 2:
        print("用法:")
        print("  python patch_tcl_version_guard.py <tcl文件或目录>")
        sys.exit(1)

    target = Path(sys.argv[1])

    if not target.exists():
        print(f"[ERROR] 路径不存在: {target}")
        sys.exit(2)

    if target.is_file():
        status = patch_one_file(target, backup=True)
        print(f"[RESULT] {target} -> {status}")
    else:
        patch_directory(target, recursive=True)


if __name__ == "__main__":
    main()