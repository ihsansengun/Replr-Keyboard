#!/usr/bin/env python3
"""Recolor the Lottie accent (teal -> Flirt rose) and tag accent fills.

For every embedded Lottie JSON (the raw-string constants in the keyboard and
onboarding Swift files) and every canonical source .json, find each fill/stroke
that is the brand accent -- identified by a teal-ish color OR an existing
nm "accent" -- set its name to "accent" and bake ACCENT as a fallback color.

The app tints these at runtime via a ColorValueProvider on keypath
"**.accent.Color", so the baked color is only a fallback; the rename to "accent"
is what makes the keypath addressable. Re-runnable.
"""
import json
import re
import sys
import pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
ACCENT = [1.0, 0.435, 0.569]  # #FF6F91 baked fallback; runtime overrides adaptively


def is_teal(k):
    return (isinstance(k, list) and len(k) >= 3
            and all(isinstance(x, (int, float)) for x in k[:3])
            and k[0] < 0.30 and k[1] > 0.80 and k[2] > 0.80)


def recolor(node):
    """Recursively tag + recolor accent fills/strokes. Returns count changed."""
    n = 0
    if isinstance(node, dict):
        if node.get("ty") in ("fl", "st"):
            c = node.get("c", {})
            k = c.get("k")
            if node.get("nm") == "accent" or is_teal(k):
                node["nm"] = "accent"
                if isinstance(k, list) and len(k) == 4:
                    c["k"] = ACCENT + [k[3]]
                else:
                    c["k"] = list(ACCENT)
                n += 1
        for v in node.values():
            n += recolor(v)
    elif isinstance(node, list):
        for v in node:
            n += recolor(v)
    return n


def process_source(rel):
    p = REPO / rel
    data = json.loads(p.read_text(encoding="utf-8"))
    n = recolor(data)
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"  source   {rel}: {n} accent fill(s)")


def process_embedded(swift_rel, const):
    p = REPO / swift_rel
    s = p.read_text(encoding="utf-8")
    m = re.search(r'(' + re.escape(const) + r'\s*=\s*##")(.*?)("##)', s, re.S)
    if not m:
        sys.exit(f"ERROR: embedded const {const} not found in {swift_rel}")
    data = json.loads(m.group(2))
    n = recolor(data)
    mini = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    p.write_text(s[:m.start(2)] + mini + s[m.end(2):], encoding="utf-8")
    print(f"  embedded {const}: {n} accent fill(s), {len(mini)}B")


KB = "ReplrKeyboard/Views/IdlePanelView.swift"
OB = "Replr/Replr/Features/Onboarding/OnboardingView.swift"

print("Embedded constants:")
process_embedded(KB, "captureStepsLottieJSON")
for const in ("onboardingCelebrationLottieJSON", "tutSwitchJSON", "tutPickJSON",
              "tutMinimiseJSON", "tutScreenshotJSON", "tutSendJSON"):
    process_embedded(OB, const)

print("Source assets:")
for rel in ("ReplrKeyboard/Resources/capture_steps.json",
            "Replr/Replr/Features/Onboarding/onboarding_steps.json",
            "Replr/Replr/Features/Onboarding/tutorial_lottie/tut_switch.json",
            "Replr/Replr/Features/Onboarding/tutorial_lottie/tut_pick.json",
            "Replr/Replr/Features/Onboarding/tutorial_lottie/tut_minimise.json",
            "Replr/Replr/Features/Onboarding/tutorial_lottie/tut_screenshot.json",
            "Replr/Replr/Features/Onboarding/tutorial_lottie/tut_send.json"):
    process_source(rel)

print("done.")
