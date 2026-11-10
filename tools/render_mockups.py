#!/usr/bin/env python3
"""Renders the HTML/CSS widget mockups to PNG with headless Chromium.

Input: mockups/snapshot.json, produced on Linux by
`devwidgets-probe` (real data from DevWidgetsCore). Output goes to
docs/report/images/. These images are mockups, not macOS captures.
"""
import json
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT_PATH = Path(__file__).resolve().parent.parent
PAGE_URL = (ROOT_PATH / "mockups" / "widgets.html").as_uri()
SNAPSHOT_PATH = ROOT_PATH / "mockups" / "snapshot.json"
CONTEXT_PATH = ROOT_PATH / "mockups" / "context.json"
# `devwidgets-probe servers` against the box's local sshd.
SERVERS_PATH = ROOT_PATH / "mockups" / "servers.json"
# Recorded anonymously with an explicit reviewer instead of @me.
REVIEWS_PATH = (ROOT_PATH / "Tests" / "Fixtures" / "github"
                / "search-review-requested.json")
OUTPUT_PATH = ROOT_PATH / "docs" / "report" / "images"
MODES = ["light", "dark", "tinted"]
SINGLE_WIDGETS = [("small", "cpu"), ("small", "network"),
                  ("medium", "memory")]
SCALE_FACTOR = 2
VIEWPORT = {"width": 860, "height": 600}


def renderPage(page, script_Text, output_Name, selector="body"):
    page.goto(PAGE_URL)
    page.evaluate(script_Text)
    page.wait_for_timeout(150)
    page.locator(selector).screenshot(
        path=str(OUTPUT_PATH / output_Name))
    print("wrote", output_Name)


def loadReviewQueue():
    """Mirrors ReviewQueueParser: drafts are not awaiting review."""
    payload = json.loads(REVIEWS_PATH.read_text())
    requests = [
        {"repository": {"name": item["repository_url"]
                        .rsplit("/", 1)[1]},
         "number": item["number"], "title": item["title"]}
        for item in payload["items"] if not item.get("draft")]
    return {"total_Count": payload["total_count"],
            "requests": requests}


def renderPhaseFive(page, inputs):
    context_Json, servers_Json, queue_Json = inputs
    for mode in ["light", "dark"]:
        renderPage(page, f"renderServers({servers_Json}, '{mode}')",
                   f"mockup-servers-{mode}.png")
    renderPage(page, f"renderServerSettings({servers_Json})",
               "mockup-settings-servers.png")
    renderPage(page,
               f"renderReviewsAndCI({context_Json}, {queue_Json})",
               "mockup-reviews-ci.png")


def renderAll(page, snapshot_Json, context_Json, extras):
    for mode in MODES:
        renderPage(page, f"renderGallery({snapshot_Json}, '{mode}')",
                   f"mockup-gallery-{mode}.png")
        for size, kind in SINGLE_WIDGETS:
            renderPage(
                page,
                f"renderSingle({snapshot_Json}, '{mode}', "
                f"'{size}', '{kind}')",
                f"mockup-{size}-{kind}-{mode}.png", "#single")
        renderPage(page,
                   f"renderDashboards({snapshot_Json}, '{mode}')",
                   f"mockup-dashboards-{mode}.png")
        renderPage(page, f"renderContext({context_Json}, '{mode}', "
                   f"{extras['reviews']})",
                   f"mockup-context-{mode}.png")
    extras_Json = (f"{{servers: {extras['servers']}, "
                   f"reviews: {extras['reviews']}}}")
    renderPage(page, f"renderPanel({snapshot_Json}, {context_Json},"
               f" {extras_Json})", "mockup-menubar-panel.png")
    renderPage(page, f"renderActions({context_Json})",
               "mockup-actions-confirm.png")
    renderPage(page, "renderAlerts()", "mockup-alerts.png")
    renderPage(page, f"renderGitHubSettings({context_Json})",
               "mockup-settings-github.png")
    renderPhaseFive(page, (context_Json, extras["servers"],
                           extras["reviews"]))


def main():
    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)
    snapshot_Json = json.dumps(json.loads(SNAPSHOT_PATH.read_text()))
    context_Json = json.dumps(json.loads(CONTEXT_PATH.read_text()))
    extras = {
        "servers": json.dumps(json.loads(SERVERS_PATH.read_text())),
        "reviews": json.dumps(loadReviewQueue()),
    }
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        page = browser.new_page(device_scale_factor=SCALE_FACTOR,
                                viewport=VIEWPORT)
        renderAll(page, snapshot_Json, context_Json, extras)
        browser.close()


if __name__ == "__main__":
    main()
