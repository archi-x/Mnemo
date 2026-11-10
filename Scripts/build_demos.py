#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 demo_src/*.py 里的手写内容合成 Mnemo/Resources/methoddemos.json。

每个方法 = 浅 / 中 / 深 三份材料，逐行对应 methods.json 里该方法自己的步骤。
步骤名在 STEPS 里统一维护，保证「步骤区」和「三例」用的是同一套词。
"""
import json, os, sys, importlib.util, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Mnemo", "Resources")

STEPS = {
    1: ["提取关键词", "变成具体对象", "加颜色大小动作", "与含义发生关系", "闭眼回收"],
    2: ["找核心特征", "设计互动", "加动作和结果", "双向回忆", "还原含义"],
    3: ["确定顺序", "一项一画面", "前后接因果", "控制长度", "正序倒序抽测"],
    4: ["先画普通画面", "选夸张维度", "不改关键词", "回忆还原"],
    5: ["找冲突与代价", "代入现场", "贴情绪词", "先情绪后事件"],
    6: ["选熟悉空间", "定路线不交叉", "给位置编号", "一位一单元", "内容变图", "正倒序随机"],
    7: ["选熟悉路线", "标出地标", "间隔要明确", "一地标一信息", "按方向回忆"],
    8: ["一房一主题", "固定十个位", "同主题同房", "换主题换房"],
    9: ["固定身体顺序", "一位一信息", "用动作强化", "头脚两头走"],
    10: ["选一组物件", "固定物件顺序", "信息挂上去", "先物后信息"],
    11: ["建 0-9 形象", "形象长期不改", "数字串分组", "每组一画面", "先图后数"],
    12: ["固定谐音表", "切 2-4 位", "转词组短句", "加图加动作", "先画后数"],
    13: ["给字母定词", "固定顺序", "与桩互动", "按字母回忆"],
    14: ["选十个人物", "固定顺序", "配动作道具", "与人物互动"],
    15: ["画一条轴", "标出阶段", "写关键事件", "标出转折", "箭头连因果"],
    16: ["找近似音", "近似词进画面", "音形同时检查", "双向回忆"],
    17: ["读准单词", "找熟悉部分", "设计含义画面", "记拼写关键", "中英双向"],
    18: ["提取首字母", "尝试组成词", "给缩写赋义", "还原全项"],
    19: ["提取首字", "组成通顺句", "一字对一项", "从字到全项"],
    20: ["提取关键点", "压缩成短句", "押韵或等长", "一句一关键词", "口诀后解释"],
    21: ["通读材料", "找自然边界", "三到五项一组", "给组命名", "先组名后组内"],
    22: ["定分类标准", "标准互斥", "每类不超七项", "给类别命名", "类间类内提取"],
    23: ["写总主题", "分出大模块", "模块下写要点", "要点下写细节", "逐级遮盖回忆"],
    24: ["中心写主题", "一级写大类", "二级写关键词", "颜色分模块", "箭头连关系", "合上重画"],
    25: ["行写对象", "列写维度", "格内填关键词", "标最大差异", "遮表回忆"],
    26: ["写起终点", "列出步骤", "标判断点", "标分支循环", "凭记忆重画"],
    27: ["根写总概念", "干写大类", "枝写子类", "叶写例子", "根叶双向"],
    28: ["找目标结构", "选熟悉事物", "一一对应", "说清有效处", "说清失效处"],
    29: ["找一个情境", "明确问题", "应用知识", "写结论理由", "换个情境再用"],
    30: ["读出声", "画图", "写关键词", "手势或走动", "录音复听", "讲给人听"],
    31: ["把信息分步", "每步一动作", "动作扣含义", "边做边说", "去掉动作复述"],
    32: ["建符号表", "符号表关系", "保持符号一致", "符号还原成句"],
    33: ["一句话说核心", "找三到五要素", "说明要素关系", "画出模型", "加例外细节"],
    34: ["写定义", "找正例", "找近似反例", "说判断标准", "混合判断"],
    35: ["读一小节", "合上材料", "写出要点", "对照标遗漏", "只重练遗漏"],
    36: ["一卡一问", "正问背答", "先自测后翻面", "标三类状态", "只重练前两类"],
    37: ["立即回忆", "当天睡前", "次日复习", "三天后", "七天后", "半月后"],
    38: ["混编练习", "每组多类型", "先判题型", "记判断错误", "专练判断错"],
    39: ["抄录原题", "写错答正答", "分类错因", "写识别信号", "重做原题", "做变式题", "三日后复测"],
    40: ["选一个概念", "设想初中生", "讲 1-3 分钟", "录音或写稿", "标出卡壳处", "回材料补齐", "再讲加例子"],
}

LEVELS = ["浅", "中", "深"]


def load_module(path):
    name = "demo_" + os.path.basename(path).replace(".py", "")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    methods = json.load(open(os.path.join(RES, "methods.json"), encoding="utf-8"))["methods"]
    by_id = {m["id"]: m for m in methods}

    decks = {}
    for path in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "demo_src", "*.py"))):
        mod = load_module(path)
        for mid, deck in getattr(mod, "DECKS", {}).items():
            if mid in decks:
                sys.exit("重复定义方法 %s（%s）" % (mid, path))
            decks[mid] = deck

    # 方法 1 的三例保留原稿
    old = json.load(open(os.path.join(RES, "methoddemos.json"), encoding="utf-8"))["demos"]
    old_first = {d["methodId"]: d for d in old}.get(1)

    out, problems = [], []
    for m in methods:
        mid = m["id"]
        if mid == 1 and old_first and mid not in decks:
            out.append(old_first)
            continue
        if mid not in decks:
            problems.append("缺内容：%s %s" % (mid, m["name"]))
            continue
        deck = decks[mid]
        cases = deck["cases"]
        if len(cases) != 3:
            problems.append("%s 档位不足：%d" % (m["name"], len(cases)))
        if [c["level"] for c in cases] != LEVELS:
            problems.append("%s 档位顺序不是浅中深" % m["name"])
        steps = STEPS[mid]
        if len(steps) != len(m["steps"]):
            problems.append("%s 步骤名数量 %d ≠ 原始步骤 %d" % (m["name"], len(steps), len(m["steps"])))
        built_cases = []
        for i, c in enumerate(cases):
            if len(c["steps"]) != len(steps):
                problems.append("%s·%s 过程 %d 行 ≠ 步骤 %d" % (m["name"], c["level"], len(c["steps"]), len(steps)))
            if not c["items"]:
                problems.append("%s·%s 没有元素" % (m["name"], c["level"]))
            built_cases.append({
                "id": "m%d-d%d" % (mid, i + 1),
                "level": c["level"],
                "levelNote": c["levelNote"],
                "title": c["title"],
                "material": c["material"],
                "items": [{"text": t, "emoji": e} for t, e in c["items"]],
                "trace": [{"step": s, "text": t} for s, t in zip(steps, c["steps"])],
                "built": c["built"],
                "tip": c["tip"],
            })
        out.append({
            "methodId": mid,
            "methodName": m["name"],
            "intro": deck["intro"],
            "cases": built_cases,
        })

    if problems:
        print("校验未通过：")
        for p in problems:
            print("  -", p)
        sys.exit(1)

    payload = {"version": 2, "demos": out}
    with open(os.path.join(RES, "methoddemos.json"), "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
        f.write("\n")
    total = sum(len(d["cases"]) for d in out)
    print("写入 %d 门方法 / %d 份演示" % (len(out), total))


if __name__ == "__main__":
    main()
