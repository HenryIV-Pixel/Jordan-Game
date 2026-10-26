"""Click through the built game in a headless browser and save screenshots.

Usage: npm run build && npx vite preview --port 4173 &  then  python3 tools/screenshots.py OUT_DIR
"""
import sys
from playwright.sync_api import sync_playwright

OUT = sys.argv[1]
URL = "http://localhost:4173/"
errors = []

with sync_playwright() as p:
    b = p.chromium.launch()
    page = b.new_page(viewport={"width": 1600, "height": 900})
    page.on("console", lambda m: errors.append(f"{m.type}: {m.text}") if m.type in ("error", "warning") else None)
    page.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
    page.goto(URL)
    page.evaluate("localStorage.clear()")
    page.reload()
    page.wait_for_timeout(800)
    page.screenshot(path=f"{OUT}/01-menu.png")
    page.get_by_role("button", name="لعبة جديدة").click()
    page.wait_for_timeout(300)
    page.screenshot(path=f"{OUT}/02-newgame-1.png")
    page.get_by_role("button", name="التالي: اختر البلدية ←").click()
    page.wait_for_timeout(300)
    page.screenshot(path=f"{OUT}/03-newgame-2.png")
    page.get_by_role("button", name="التالي: الاسم والسمات ←").click()
    page.wait_for_timeout(300)
    page.screenshot(path=f"{OUT}/04-newgame-3.png")
    page.get_by_role("button", name="ابدأ المسيرة").click()
    page.wait_for_timeout(500)
    page.screenshot(path=f"{OUT}/05-event.png")
    page.get_by_role("radio").nth(1).click()
    page.get_by_role("button", name="تأكيد الاختيار").click()
    page.wait_for_timeout(400)
    page.screenshot(path=f"{OUT}/06-main.png")
    for name, fn in [("الشخصية", "07-character"), ("شبكة العلاقات", "08-network"), ("البلدية", "09-municipality")]:
        page.get_by_role("navigation").get_by_role("button", name=name, exact=True).click()
        page.wait_for_timeout(300)
        page.screenshot(path=f"{OUT}/{fn}.png")
    # play a few weeks: approve permits and end turns, resolving any events with the first open option
    for week in range(6):
        page.get_by_role("navigation").get_by_role("button", name="البلدية", exact=True).click()
        for _ in range(3):
            btns = page.get_by_role("button", name="أنجِز")
            if btns.count() and btns.first.is_enabled():
                btns.first.click()
                page.wait_for_timeout(80)
        page.get_by_role("button", name="إنهاء الأسبوع").click()
        page.wait_for_timeout(250)
        while page.get_by_role("dialog").count():
            radios = page.get_by_role("radio")
            if radios.count():
                radios.first.click()
                page.get_by_role("button", name="تأكيد الاختيار").click()
            else:
                page.get_by_role("button", name="قرّر لاحقاً").click()
            page.wait_for_timeout(200)
    page.get_by_role("navigation").get_by_role("button", name="الخريطة", exact=True).click()
    page.wait_for_timeout(300)
    page.screenshot(path=f"{OUT}/10-main-week7.png")
    page.get_by_role("navigation").get_by_role("button", name="البلدية", exact=True).click()
    page.wait_for_timeout(300)
    page.screenshot(path=f"{OUT}/11-municipality-week7.png")
    page.get_by_role("button", name="القائمة: حفظ وتحميل").click()
    page.wait_for_timeout(200)
    page.screenshot(path=f"{OUT}/12-menu-ingame.png")
    b.close()

print("\n".join(errors) if errors else "no console errors")
