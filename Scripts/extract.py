#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 Obsidian 里的《记忆法全景手册》《记忆法儿童版》抽取成 App 用的结构化 JSON。"""

import json
import re
from pathlib import Path

VAULT = Path("/Users/tal/Library/Mobile Documents/iCloud~md~obsidian/Documents/archie/05-个人成长/记忆训练")
OUT = Path("/Users/tal/WorkBuddy/Claw/Mnemo/Mnemo/Resources")

CATEGORY_META = {
    "编码基础": ("code", "square.stack.3d.up.fill"),
    "空间与位置": ("space", "cube.transparent.fill"),
    "序列与挂钩": ("seq", "number.square.fill"),
    "语言转化": ("lang", "textformat.abc"),
    "结构组织": ("struct", "square.grid.3x3.fill"),
    "深度加工": ("deep", "brain.head.profile"),
    "复习提取": ("review", "arrow.triangle.2.circlepath"),
}


def clean(line: str) -> str:
    line = line.strip()
    if line.startswith("!["):
        return ""
    line = re.sub(r"^[-*]\s+", "", line)
    line = re.sub(r"^\d+[.、]\s*", "", line)
    line = line.replace("**", "").replace("`", "")
    return line.strip()


def blocks(text: str):
    """按 '### 标题' 切成 (标题, 内容行列表)。"""
    out, title, buf = [], None, []
    for line in text.splitlines():
        if line.startswith("### "):
            if title:
                out.append((title, buf))
            title, buf = line[4:].strip(), []
        elif line.strip() == "---" and title:
            out.append((title, buf))
            title, buf = None, []
        elif title:
            buf.append(line)
    if title:
        out.append((title, buf))
    return out


def bullets(lines):
    return [clean(l) for l in lines if clean(l)]


def first_text(block: str) -> str:
    for l in block.splitlines():
        if clean(l):
            return clean(l)
    return ""


def main():
    raw = (VAULT / "记忆法全景手册.md").read_text(encoding="utf-8")
    lines = raw.splitlines()

    # 1) 切出方法块
    methods, cur, cur_cat = [], None, None
    chapter_of_cat = {}
    for line in lines:
        m = re.match(r"^# 第.类：(.+)$", line.strip())
        if m:
            cur_cat = m.group(1).strip()
            continue
        m = re.match(r"^## (\d{2}) +(.+)$", line.strip())
        if m and cur_cat:
            if cur:
                methods.append(cur)
            cur = {"code": m.group(1), "name": m.group(2).strip(), "category": cur_cat, "body": []}
            continue
        if line.startswith("# 附录"):
            if cur:
                methods.append(cur)
                cur = None
            cur_cat = None
            continue
        if line.startswith("# ") and cur:
            methods.append(cur)
            cur = None
        if cur is not None:
            cur["body"].append(line)
    if cur:
        methods.append(cur)

    # 2) 解析每一个方法
    out_methods = []
    for m in methods:
        sec = {t: b for t, b in blocks("\n".join(m["body"]))}
        _, lvl = "def", None

        def para(key):
            return " ".join(bullets(sec.get(key, [])))

        case_lines = bullets(sec.get("案例", []))
        case_title = ""
        if len(case_lines) == 1 and len(case_lines[0]) > 24:
            t = case_lines[0]
            head, _, rest = t.partition("：")
            if len(head) <= 22 and rest:
                case_title = head
                case_lines = [x.strip() + "。" for x in rest.split("。") if x.strip()]
        elif case_lines and "：" in case_lines[0] and len(case_lines[0]) <= 40:
            case_title = case_lines[0].rstrip("：")
            case_lines = case_lines[1:]
        case_body = case_lines
        norm = []
        for l in case_body:
            if re.match(r"^\|[\s\-|:]+\|?$", l):
                continue
            if l.startswith("|"):
                cells = [c.strip() for c in l.strip("|").split("|")]
                if len(cells) >= 2:
                    norm.append(f"{cells[0]}：{'，'.join(cells[1:])}")
                continue
            norm.append(l)
        case_body = norm

        practice = []
        for row in sec.get("举一反三练习", []):
            cells = [c.strip() for c in row.strip().strip("|").split("|")]
            if len(cells) >= 2 and cells[0] in ("初阶", "中阶", "高阶"):
                practice.append({"level": cells[0], "task": cells[1]})

        cat_id, icon = CATEGORY_META.get(m["category"], ("code", "square.grid.2x2.fill"))
        out_methods.append({
            "id": int(m["code"]),
            "code": m["code"],
            "name": m["name"],
            "categoryId": cat_id,
            "categoryName": m["category"],
            "icon": icon,
            "definition": para("定义"),
            "principle": para("原理"),
            "bestFor": bullets(sec.get("最适合", [])),
            "notFor": bullets(sec.get("不适合", [])),
            "steps": bullets(sec.get("使用步骤", [])),
            "caseTitle": case_title.replace("：", "") if case_title else "",
            "caseLines": case_body,
            "practice": practice,
            "mistakes": bullets(sec.get("常见错误", [])),
            "combo": para("组合建议"),
        })

    # 3) 合并儿童版：一句话解释 + 初阶案例 1
    kid_dir = VAULT / "记忆法儿童版"
    for m in out_methods:
        f = kid_dir / f"{m['code']}-{m['name']}.md"
        if not f.exists():
            cand = list(kid_dir.glob(f"{m['code']}-*.md"))
            f = cand[0] if cand else None
        if not f:
            continue
        text = f.read_text(encoding="utf-8")
        one = re.search(r"一句话解释\n(?:>\s*)+(.*)", text)
        m["kidLine"] = clean(one.group(1)) if one else ""
        case = re.search(r"### 案例 1：(.+?)\n(.*?)(?=\n### 案例 2|\Z)", text, re.S)
        if case:
            body = case.group(2)
            mat = re.search(r"#### 案例材料\n(.*?)(?=\n#### )", body, re.S)
            stp = re.search(r"#### 记忆步骤\n(.*?)(?=\n#### )", body, re.S)
            tip = re.search(r"#### 记忆技巧\n(.*?)(?=\n#### )", body, re.S)
            mis = re.search(r"\*\*常见错误\*\*\n(.*?)(?=\n\*\*|\Z)", body, re.S)
            m["kidCase"] = {
                "title": case.group(1).strip(),
                "material": clean(mat.group(1).replace("\n", " ")) if mat else "",
                "steps": bullets(stp.group(1).splitlines()) if stp else [],
                "tip": first_text(tip.group(1)) if tip else "",
                "mistakes": bullets(mis.group(1).splitlines()) if mis else [],
            }

    # 4) 诊断表 / 选法诊断 / 三十天计划
    diag_section = raw.split("### 1. 先诊断，再选法")[1].split("### 2.")[0]
    diagnose = []
    for row in diag_section.splitlines():
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cells) >= 2 and cells[0] not in ("你的问题", "---") and cells[0]:
            diagnose.append({"symptom": cells[0], "methods": cells[1]})

    plan_section = raw.split("# 附录四：三十天训练计划")[1].split("# 附录五")[0]
    plan = []
    for row in plan_section.splitlines():
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cells) >= 3 and cells[0].isdigit():
            plan.append({"day": int(cells[0]), "theme": cells[1], "task": cells[2]})

    fix_section = raw.split("# 附录五：诊断表")[1].split("# 附录六")[0]
    fixes = []
    for row in fix_section.splitlines():
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cells) >= 3 and cells[0] not in ("症状", "---") and cells[0]:
            fixes.append({"symptom": cells[0], "cause": cells[1], "fix": cells[2]})

    cats = []
    for name, (cid, icon) in CATEGORY_META.items():
        members = [m for m in out_methods if m["categoryId"] == cid]
        cats.append({"id": cid, "name": name, "icon": icon,
                     "range": f"{members[0]['code']}–{members[-1]['code']}" if members else "",
                     "count": len(members)})

    payload = {
        "version": 1,
        "source": "记忆法全景手册 + 记忆法儿童版 + 定位记忆法与联想记忆法训练手册",
        "categories": cats,
        "methods": out_methods,
        "diagnose": diagnose,
        "fixes": fixes,
        "plan": plan,
    }

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "methods.json").write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")

    n_kid = sum(1 for m in out_methods if m.get("kidCase"))
    print(f"方法 {len(out_methods)} 个 / 分类 {len(cats)} / 诊断 {len(diagnose)} / 计划 {len(plan)} 天 / 儿童案例 {n_kid}")
    miss = [m["code"] + m["name"] for m in out_methods if not m["definition"] or not m["steps"]]
    print("缺字段:", miss or "无")


if __name__ == "__main__":
    main()
