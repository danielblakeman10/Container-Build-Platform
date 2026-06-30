#!/usr/bin/env python3
"""Generate diagram PNGs for the Container Build Platform tutorial."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import os

OUT = os.path.dirname(os.path.abspath(__file__))

# Color palette
BLUE = "#2563eb"
GREEN = "#16a34a"
ORANGE = "#ea580c"
PURPLE = "#7c3aed"
RED = "#dc2626"
GRAY = "#475569"
TEAL = "#0d9488"
DARK = "#1e293b"


def box(ax, x, y, w, h, text, color, fontsize=10, text_color="white"):
    p = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.08",
                       linewidth=1.5, edgecolor=color, facecolor=color, alpha=0.92)
    ax.add_patch(p)
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center",
            fontsize=fontsize, color=text_color, weight="bold", wrap=True)


def arrow(ax, x1, y1, x2, y2, color=DARK, style="-|>", lw=2):
    a = FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style, mutation_scale=18,
                        linewidth=lw, color=color, connectionstyle="arc3,rad=0")
    ax.add_patch(a)


# ============================================================
# Diagram 1: High-level pipeline flow
# ============================================================
def diagram_pipeline():
    fig, ax = plt.subplots(figsize=(11, 3.2))
    ax.set_xlim(0, 22); ax.set_ylim(0, 6); ax.axis("off")
    stages = [
        ("Git Push\n(trigger)", GRAY),
        ("BUILD\nmulti-arch\nimage", BLUE),
        ("TEST\nunit tests\nin build", TEAL),
        ("SCAN\nTrivy CVE\n+ config", ORANGE),
        ("PUSH\nto AWS ECR", GREEN),
        ("SIGN\nCosign +\nSBOM", PURPLE),
    ]
    w, h, gap = 3.0, 2.6, 0.55
    x = 0.4
    y = 1.8
    centers = []
    for label, color in stages:
        box(ax, x, y, w, h, label, color, fontsize=9.5)
        centers.append((x + w, y + h / 2))
        x += w + gap
    # arrows between
    xx = 0.4
    for i in range(len(stages) - 1):
        x1 = xx + w
        x2 = xx + w + gap
        arrow(ax, x1, y + h / 2, x2, y + h / 2)
        xx += w + gap
    # gate annotations
    ax.text(0.4 + 3*(w+gap) + w/2, y - 0.5, "FAIL on Critical CVE",
            ha="center", fontsize=8, color=RED, style="italic")
    ax.text(11, 5.5, "Container Build Pipeline — Stage Flow", ha="center",
            fontsize=13, weight="bold", color=DARK)
    plt.tight_layout()
    fig.savefig(os.path.join(OUT, "diagram_pipeline.png"), dpi=150, bbox_inches="tight")
    plt.close(fig)


# ============================================================
# Diagram 2: Multi-stage Docker build
# ============================================================
def diagram_multistage():
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.set_xlim(0, 20); ax.set_ylim(0, 11); ax.axis("off")
    ax.text(10, 10.4, "Multi-Stage Docker Build — How Layers Are Discarded",
            ha="center", fontsize=13, weight="bold", color=DARK)

    # Stage 1 builder
    box(ax, 0.5, 6.5, 6, 3, "STAGE 1: builder\n(golang:1.21-alpine)\n\n• go mod download\n• go build -> /server\n• go test", BLUE, fontsize=9)
    # Stage 2 certs
    box(ax, 0.5, 2.5, 6, 3, "STAGE 2: certs\n(alpine:3.19)\n\n• ca-certificates", TEAL, fontsize=9)
    # Stage 3 final
    box(ax, 12, 4, 7, 4, "STAGE 3: FINAL\n(FROM scratch)\n\n• /server binary only\n• ca-certificates\n• USER 65534\n• ~10 MB image", GREEN, fontsize=9.5)

    arrow(ax, 6.5, 8.0, 12, 7.0, color=BLUE, lw=2.2)
    ax.text(9.2, 7.9, "COPY --from=builder\n/server", ha="center", fontsize=8, color=BLUE)
    arrow(ax, 6.5, 4.0, 12, 5.2, color=TEAL, lw=2.2)
    ax.text(9.2, 4.1, "COPY --from=certs\nca-certs", ha="center", fontsize=8, color=TEAL)

    ax.text(3.5, 1.8, "Build tools, source code, Go compiler\nNEVER ship to production",
            ha="center", fontsize=8.5, color=RED, style="italic")
    plt.tight_layout()
    fig.savefig(os.path.join(OUT, "diagram_multistage.png"), dpi=150, bbox_inches="tight")
    plt.close(fig)


# ============================================================
# Diagram 3: Tagging strategy
# ============================================================
def diagram_tagging():
    fig, ax = plt.subplots(figsize=(10, 4.5))
    ax.set_xlim(0, 20); ax.set_ylim(0, 9); ax.axis("off")
    ax.text(10, 8.4, "Image Tagging Strategy — One Build, Many Tags",
            ha="center", fontsize=13, weight="bold", color=DARK)
    box(ax, 7, 5.5, 6, 2, "Single Image Digest\nsha256:a3f9...", DARK, fontsize=10)
    tags = [
        ("latest", GREEN, 0.5),
        ("1.4.2\n(semver)", BLUE, 4.4),
        ("1.4 / 1\n(range)", TEAL, 8.3),
        ("abc1234\n(commit SHA)", ORANGE, 12.2),
        ("20260630-abc1234\n(timestamp)", PURPLE, 15.8),
    ]
    for label, color, x in tags:
        box(ax, x, 1.2, 3.4, 2, label, color, fontsize=8.5)
        arrow(ax, 10, 5.5, x + 1.7, 3.2, color=color, lw=1.6)
    plt.tight_layout()
    fig.savefig(os.path.join(OUT, "diagram_tagging.png"), dpi=150, bbox_inches="tight")
    plt.close(fig)


# ============================================================
# Diagram 4: AWS architecture / OIDC auth
# ============================================================
def diagram_aws():
    fig, ax = plt.subplots(figsize=(10, 5.5))
    ax.set_xlim(0, 20); ax.set_ylim(0, 12); ax.axis("off")
    ax.text(10, 11.4, "AWS Integration & Authentication Flow",
            ha="center", fontsize=13, weight="bold", color=DARK)

    box(ax, 0.5, 8, 5, 2.2, "GitHub Actions\nRunner", GRAY, fontsize=10)
    box(ax, 0.5, 4.5, 5, 2.2, "AWS CodeBuild\n(alternative)", GRAY, fontsize=10)
    box(ax, 7.5, 6.2, 5, 2.6, "IAM Role\n(OIDC / keys)\nleast privilege", RED, fontsize=9.5)
    box(ax, 14.5, 8.5, 5, 2.4, "Amazon ECR\nimage registry", GREEN, fontsize=10)
    box(ax, 14.5, 5, 5, 2.4, "S3 Bucket\nSBOM storage", ORANGE, fontsize=10)
    box(ax, 14.5, 1.5, 5, 2.4, "ECR Lifecycle\nPolicy + cleanup", PURPLE, fontsize=9.5)

    arrow(ax, 5.5, 9.1, 7.5, 7.8, color=DARK)
    arrow(ax, 5.5, 5.6, 7.5, 7.0, color=DARK)
    arrow(ax, 12.5, 7.8, 14.5, 9.3, color=GREEN)
    arrow(ax, 12.5, 7.2, 14.5, 6.0, color=ORANGE)
    arrow(ax, 12.5, 6.6, 14.5, 2.6, color=PURPLE)
    ax.text(6.5, 8.0, "assume\nrole", ha="center", fontsize=7.5, color=RED)
    plt.tight_layout()
    fig.savefig(os.path.join(OUT, "diagram_aws.png"), dpi=150, bbox_inches="tight")
    plt.close(fig)


# ============================================================
# Diagram 5: CI job dependency graph
# ============================================================
def diagram_jobgraph():
    fig, ax = plt.subplots(figsize=(10, 4))
    ax.set_xlim(0, 20); ax.set_ylim(0, 8); ax.axis("off")
    ax.text(10, 7.4, "ci.yml — Job Dependency Graph (needs:)",
            ha="center", fontsize=13, weight="bold", color=DARK)
    box(ax, 0.5, 3, 3.2, 2, "build\n& test", BLUE, fontsize=10)
    box(ax, 5, 3, 3.2, 2, "scan\n(Trivy)", ORANGE, fontsize=10)
    box(ax, 9.5, 3, 3.2, 2, "push-ecr", GREEN, fontsize=10)
    box(ax, 14, 3, 3.2, 2, "sign\n(Cosign)", PURPLE, fontsize=10)
    box(ax, 14, 0.2, 3.2, 1.8, "notify", GRAY, fontsize=10)
    arrow(ax, 3.7, 4, 5, 4)
    arrow(ax, 8.2, 4, 9.5, 4)
    arrow(ax, 12.7, 4, 14, 4)
    arrow(ax, 11.1, 3, 15.6, 2.0, color=GRAY)
    ax.text(10, 5.4, "each 'needs:' the previous — failure stops the chain",
            ha="center", fontsize=8.5, color=RED, style="italic")
    plt.tight_layout()
    fig.savefig(os.path.join(OUT, "diagram_jobgraph.png"), dpi=150, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    diagram_pipeline()
    diagram_multistage()
    diagram_tagging()
    diagram_aws()
    diagram_jobgraph()
    print("Diagrams written to", OUT)
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png"):
            print("  ", f, os.path.getsize(os.path.join(OUT, f)), "bytes")
