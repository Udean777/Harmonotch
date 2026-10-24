"use strict";

// Year
const yearEl = document.getElementById("year");
if (yearEl) yearEl.textContent = String(new Date().getFullYear());

// Mobile nav
const hamburger = document.getElementById("hamburger");
const navLinks = document.getElementById("navLinks");
if (hamburger && navLinks) {
  const setMenuOpen = (open) => {
    navLinks.classList.toggle("open", open);
    hamburger.setAttribute("aria-expanded", String(open));
  };
  hamburger.addEventListener("click", () =>
    setMenuOpen(!navLinks.classList.contains("open"))
  );
  hamburger.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      setMenuOpen(false);
      hamburger.focus();
    }
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && navLinks.classList.contains("open")) {
      setMenuOpen(false);
      hamburger.focus();
    }
  });
  navLinks
    .querySelectorAll("a")
    .forEach((a) => a.addEventListener("click", () => setMenuOpen(false)));
}

// Nav shadow on scroll
const nav = document.querySelector(".nav");
if (nav) {
  const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 12);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
}

// Toast helper
const toastEl = document.getElementById("toast");
let toastTimer;
function showToast(msg) {
  if (!toastEl) {
    alert(msg);
    return;
  }
  toastEl.textContent = msg;
  toastEl.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toastEl.classList.remove("show"), 3500);
}

// Dynamic Release Fetcher from GitHub API
const REPO_OWNER = "Udean777";
const REPO_NAME = "Harmonotch";
const GITHUB_API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`;
const GITHUB_FALLBACK_URL = `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases`;
const DL_ENDPOINT = "/api/download";

let latestReleaseInfo = {
  version: "v1.0.0",
  fileName: "Harmonotch-1.0.0.dmg",
  sizeFormatted: "",
  downloadUrl: DL_ENDPOINT
};

async function fetchLatestRelease() {
  const versionBadge = document.getElementById("versionBadge");
  const downloadLabels = document.querySelectorAll(".js-download-label");

  try {
    const res = await fetch(GITHUB_API_URL, {
      headers: { "Accept": "application/vnd.github.v3+json" }
    });

    if (res.ok) {
      const data = await res.json();
      const tagName = data.tag_name || "v1.0.0";
      const cleanVer = tagName.replace(/^v/, "");
      let dmgSize = "";
      let exactDmgName = `Harmonotch-${cleanVer}.dmg`;

      if (data.assets && Array.isArray(data.assets)) {
        const dmgAsset = data.assets.find(a => a.name && a.name.endsWith(".dmg"));
        if (dmgAsset) {
          exactDmgName = dmgAsset.name;
          if (dmgAsset.size) {
            const mb = (dmgAsset.size / (1024 * 1024)).toFixed(1);
            dmgSize = `${mb} MB`;
          }
        }
      }

      latestReleaseInfo.version = tagName;
      latestReleaseInfo.fileName = exactDmgName;
      latestReleaseInfo.sizeFormatted = dmgSize;

      const dynamicDlUrl = `${DL_ENDPOINT}?file=${encodeURIComponent(exactDmgName)}&tag=${encodeURIComponent(tagName)}`;
      latestReleaseInfo.downloadUrl = dynamicDlUrl;

      // Update all download buttons with exact release file name & query params
      document.querySelectorAll("a.js-download").forEach(a => {
        a.setAttribute("href", dynamicDlUrl);
        a.setAttribute("download", exactDmgName);
      });

      if (versionBadge) {
        versionBadge.textContent = `${tagName} ${dmgSize ? "· " + dmgSize : ""}`;
      }

      downloadLabels.forEach(el => {
        const lang = document.documentElement.lang || "id";
        const prefix = lang === "en" ? "Download for macOS" : "Unduh untuk macOS";
        el.textContent = `${prefix} (${exactDmgName}${dmgSize ? " · " + dmgSize : ""})`;
      });
    } else {
      // Fallback
      if (versionBadge) versionBadge.textContent = "v1.0.0 (Latest)";
    }
  } catch (err) {
    console.warn("Could not query GitHub releases API, using default values:", err);
    if (versionBadge) versionBadge.textContent = "v1.0.0 (Latest)";
  }
}

// Wire download links
for (const a of document.querySelectorAll("a.js-download")) {
  a.setAttribute("href", DL_ENDPOINT);
  a.setAttribute("download", "Harmonotch.dmg");
  a.addEventListener("click", () => {
    const targetUrl = a.getAttribute("href") || DL_ENDPOINT;
    // Non-blocking availability check
    fetch(targetUrl, { method: "HEAD" })
      .then((r) => {
        if (!r.ok) {
          const lang = document.documentElement.lang === "en" ? "en" : "id";
          showToast(
            lang === "en"
              ? "Direct download unavailable, opening GitHub Releases..."
              : "Unduhan langsung belum tersedia, membuka GitHub Releases..."
          );
          setTimeout(() => window.open(GITHUB_FALLBACK_URL, "_blank", "noopener"), 1000);
        }
      })
      .catch(() => {});
  });
}

// Copy Command Button
const copyCommandBtn = document.getElementById("copyCommandBtn");
if (copyCommandBtn) {
  copyCommandBtn.addEventListener("click", () => {
    const code = "xattr -cr /Applications/Harmonotch.app";
    navigator.clipboard.writeText(code).then(() => {
      const lang = document.documentElement.lang || "id";
      const originalText = copyCommandBtn.textContent;
      const copiedText = lang === "en" ? "Copied!" : "Tersalin!";
      copyCommandBtn.textContent = copiedText;
      copyCommandBtn.classList.add("copied");
      setTimeout(() => {
        copyCommandBtn.textContent = originalText;
        copyCommandBtn.classList.remove("copied");
      }, 2500);
    }).catch(err => {
      console.error("Clipboard copy failed:", err);
    });
  });
}

// Interactive Showcase Drawer Tabs
const showcaseTabs = document.querySelectorAll(".showcase-tab");
const mockupDrawers = document.querySelectorAll(".mockup-drawer");
const showcaseInfos = document.querySelectorAll(".showcase-info-pane");

function selectShowcaseTab(targetTabId) {
  showcaseTabs.forEach(tab => {
    const isActive = tab.getAttribute("data-tab") === targetTabId;
    tab.classList.toggle("active", isActive);
    tab.setAttribute("aria-selected", String(isActive));
  });

  mockupDrawers.forEach(drawer => {
    const isTarget = drawer.getAttribute("data-drawer") === targetTabId;
    drawer.classList.toggle("active", isTarget);
  });

  showcaseInfos.forEach(info => {
    const isTarget = info.getAttribute("data-info") === targetTabId;
    info.classList.toggle("active", isTarget);
  });
}

showcaseTabs.forEach(tab => {
  tab.addEventListener("click", () => {
    const tabId = tab.getAttribute("data-tab");
    if (tabId) selectShowcaseTab(tabId);
  });
});

// FAQ Accordion
const faqItems = document.querySelectorAll(".faq-item");
faqItems.forEach(item => {
  const trigger = item.querySelector(".faq-question");
  if (!trigger) return;

  trigger.addEventListener("click", () => {
    const isOpen = item.classList.contains("open");
    // Close other items
    faqItems.forEach(other => {
      if (other !== item) {
        other.classList.remove("open");
        const otherTrigger = other.querySelector(".faq-question");
        if (otherTrigger) otherTrigger.setAttribute("aria-expanded", "false");
      }
    });

    item.classList.toggle("open", !isOpen);
    trigger.setAttribute("aria-expanded", String(!isOpen));
  });
});

// i18n Logic
function applyLang(lang) {
  const d = (window.dict && (window.dict[lang] || window.dict.id)) || {};
  document.documentElement.lang = lang;

  // Text translations
  for (const el of document.querySelectorAll("[data-i18n]")) {
    const key = el.getAttribute("data-i18n");
    const val = d[key];
    if (val == null) continue;

    const hasSvg = el.querySelector("svg");
    if (val.includes("<")) {
      el.innerHTML = val;
      continue;
    }
    if (hasSvg && el.childNodes.length > 1) {
      const svgHtml = hasSvg.outerHTML;
      el.innerHTML = `${svgHtml} ${val}`;
    } else {
      el.textContent = val;
    }
  }

  // Attribute translations
  for (const attribute of ["alt", "aria-label", "placeholder"]) {
    for (const el of document.querySelectorAll(`[data-i18n-${attribute}]`)) {
      const key = el.getAttribute(`data-i18n-${attribute}`);
      const val = d[key];
      if (val != null) el.setAttribute(attribute, val);
    }
  }

  // Update language switcher buttons
  for (const b of document.querySelectorAll(".lang-switch button")) {
    const active = b.dataset.lang === lang;
    b.classList.toggle("active", active);
    b.setAttribute("aria-pressed", String(active));
  }

  try {
    localStorage.setItem("harmonotch_lang", lang);
  } catch {}

  document.title =
    lang === "en"
      ? "Harmonotch - The Living Notch for macOS"
      : "Harmonotch - Pusat Harmoni Notch macOS";

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc) {
    metaDesc.content =
      lang === "en"
        ? "Accurate Prayer Times & Adhan, Real-time Battery Telemetry, and Media Controls with Synced Lyrics inside your MacBook notch."
        : "Jadwal Sholat & Adzan akurat, Telemetri Baterai real-time, dan Kontrol Media dengan Lirik Sinkron di dalam notch MacBook Anda.";
  }

  // Re-run dynamic label update
  const downloadLabels = document.querySelectorAll(".js-download-label");
  const prefix = lang === "en" ? "Download for macOS" : "Unduh untuk macOS";
  downloadLabels.forEach(el => {
    const fn = latestReleaseInfo.fileName || latestReleaseInfo.version;
    const s = latestReleaseInfo.sizeFormatted;
    el.textContent = `${prefix} (${fn}${s ? " · " + s : ""})`;
  });
}

// Language init from URL or localStorage
const urlParams = new URLSearchParams(window.location.search);
const urlLang = urlParams.get("lang");
const savedLang = (() => {
  try {
    return localStorage.getItem("harmonotch_lang");
  } catch {
    return null;
  }
})();

const initialLang =
  urlLang === "en" || urlLang === "id"
    ? urlLang
    : savedLang === "en" || savedLang === "id"
      ? savedLang
      : (navigator.language || "").toLowerCase().startsWith("en")
        ? "en"
        : "id";

applyLang(initialLang);

for (const b of document.querySelectorAll(".lang-switch button")) {
  b.addEventListener("click", () => applyLang(b.dataset.lang));
}

// Initial fetch
fetchLatestRelease();

/* ------------------------------------------------------------------
   Motion layer
   ------------------------------------------------------------------ */

const prefersReducedMotion = window.matchMedia(
  "(prefers-reduced-motion: reduce)"
).matches;

// Reading progress
const progressBar = document.getElementById("scrollProgress");
if (progressBar) {
  const updateProgress = () => {
    const max =
      document.documentElement.scrollHeight - window.innerHeight;
    const ratio = max > 0 ? window.scrollY / max : 0;
    progressBar.style.transform = `scaleX(${Math.min(ratio, 1)})`;
  };
  window.addEventListener("scroll", updateProgress, { passive: true });
  window.addEventListener("resize", updateProgress, { passive: true });
  updateProgress();
}

// Living notch teaser
const heroNotch = document.getElementById("heroNotch");
if (heroNotch) {
  const notchStates = ["prayer", "battery", "media"];
  const faces = heroNotch.querySelectorAll(".hn-face");
  let stateIndex = 0;
  let notchPaused = false;

  const setNotchState = (state) => {
    heroNotch.dataset.state = state;
    faces.forEach((face) =>
      face.classList.toggle("is-on", face.dataset.face === state)
    );
  };

  heroNotch.addEventListener("mouseenter", () => (notchPaused = true));
  heroNotch.addEventListener("mouseleave", () => (notchPaused = false));

  if (!prefersReducedMotion) {
    setInterval(() => {
      if (notchPaused || document.hidden) return;
      stateIndex = (stateIndex + 1) % notchStates.length;
      setNotchState(notchStates[stateIndex]);
    }, 4200);
  }

  // Countdown ticks so the demo reads as alive
  const countdown = document.getElementById("hnCountdown");
  if (countdown) {
    let seconds = 1 * 3600 + 14 * 60 + 20;
    const pad = (n) => String(n).padStart(2, "0");
    setInterval(() => {
      seconds = seconds > 0 ? seconds - 1 : 1 * 3600 + 14 * 60 + 20;
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      const s = seconds % 60;
      countdown.textContent = `-${pad(h)}:${pad(m)}:${pad(s)}`;
    }, 1000);
  }
}

// Scroll reveal with stagger inside each group
const revealTargets = document.querySelectorAll(
  ".section-header, .trust-item, .showcase-tabs, .mockup-wrapper, " +
    ".showcase-info-container, .feature-card, .install-container, " +
    ".step-card, .faq-item, .cta-banner"
);

if (!prefersReducedMotion && "IntersectionObserver" in window) {
  const groupIndex = new Map();
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("in");
        observer.unobserve(entry.target);
      });
    },
    { threshold: 0.12, rootMargin: "0px 0px -6% 0px" }
  );

  revealTargets.forEach((el) => {
    const next = groupIndex.get(el.parentElement) || 0;
    el.style.setProperty("--i", Math.min(next, 8));
    groupIndex.set(el.parentElement, next + 1);
    el.classList.add("reveal");
    observer.observe(el);
  });
}

// Cursor spotlight on feature cards
if (!prefersReducedMotion && window.matchMedia("(pointer: fine)").matches) {
  document.querySelectorAll(".feature-card").forEach((card) => {
    card.addEventListener("pointermove", (event) => {
      const rect = card.getBoundingClientRect();
      card.style.setProperty("--mx", `${event.clientX - rect.left}px`);
      card.style.setProperty("--my", `${event.clientY - rect.top}px`);
    });
  });
}

// Gentle tilt on the MacBook mockup
const mockup = document.querySelector(".mockup-wrapper");
const mockupScreen = document.querySelector(".macbook-screen");
if (
  mockup &&
  mockupScreen &&
  !prefersReducedMotion &&
  window.matchMedia("(pointer: fine)").matches
) {
  mockup.addEventListener("pointermove", (event) => {
    const rect = mockup.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width - 0.5;
    const y = (event.clientY - rect.top) / rect.height - 0.5;
    mockupScreen.style.setProperty("--ry", `${x * 4}deg`);
    mockupScreen.style.setProperty("--rx", `${-y * 3}deg`);
  });
  mockup.addEventListener("pointerleave", () => {
    mockupScreen.style.setProperty("--ry", "0deg");
    mockupScreen.style.setProperty("--rx", "0deg");
  });
}

// Highlight the section currently in view
const sectionLinks = Array.from(
  document.querySelectorAll('.nav-links a[href^="#"]')
);
if (sectionLinks.length && "IntersectionObserver" in window) {
  const linkFor = new Map(
    sectionLinks.map((link) => [link.getAttribute("href").slice(1), link])
  );
  const sectionObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        sectionLinks.forEach((link) => link.classList.remove("active"));
        const link = linkFor.get(entry.target.id);
        if (link) link.classList.add("active");
      });
    },
    { rootMargin: "-45% 0px -50% 0px" }
  );
  linkFor.forEach((_, id) => {
    const section = document.getElementById(id);
    if (section) sectionObserver.observe(section);
  });
}
