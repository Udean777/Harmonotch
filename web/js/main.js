"use strict";

const yearEl = document.getElementById("year");
if (yearEl) yearEl.textContent = String(new Date().getFullYear());

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

const nav = document.querySelector(".nav");
if (nav) {
  const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 12);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
}

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

const REPO_OWNER = "Udean777";
const REPO_NAME = "Harmonotch";
const GITHUB_API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`;
const GITHUB_FALLBACK_URL = `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases`;
const DL_ENDPOINT = "/api/download";

async function fetchLatestRelease() {
  const versionBadge = document.getElementById("versionBadge");

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

      const dynamicDlUrl = `${DL_ENDPOINT}?file=${encodeURIComponent(exactDmgName)}&tag=${encodeURIComponent(tagName)}`;

      document.querySelectorAll("a.js-download").forEach(a => {
        a.setAttribute("href", dynamicDlUrl);
        a.setAttribute("download", exactDmgName);
      });

      if (versionBadge) {
        versionBadge.hidden = false;
        versionBadge.textContent = `${tagName} ${dmgSize ? "· " + dmgSize : ""}`;
      }
    }
  } catch (err) {
    console.warn("Could not query GitHub releases API, using fallback:", err);
  }
}

for (const a of document.querySelectorAll("a.js-download")) {
  a.setAttribute("href", DL_ENDPOINT);
  a.setAttribute("download", "Harmonotch.dmg");
  a.addEventListener("click", (event) => {
    event.preventDefault();
    const targetUrl = a.getAttribute("href") || DL_ENDPOINT;
    fetch(targetUrl, { method: "HEAD" })
      .then((r) => {
        if (r.ok) {
          window.location.href = targetUrl;
          return;
        }
        const lang = document.documentElement.lang === "en" ? "en" : "id";
        showToast(
          lang === "en"
            ? "Direct download unavailable. Opening GitHub Releases page."
            : "Unduhan langsung tidak tersedia. Membuka halaman rilis GitHub."
        );
        setTimeout(() => window.open(GITHUB_FALLBACK_URL, "_blank", "noopener"), 1000);
      })
      .catch(() => {
        window.location.href = targetUrl;
      });
  });
}

document.querySelectorAll(".copy-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    const textToCopy = btn.getAttribute("data-copy") || "xattr -cr /Applications/Harmonotch.app";
    navigator.clipboard.writeText(textToCopy).then(() => {
      const lang = document.documentElement.lang || "id";
      const originalText = btn.textContent;
      const copiedText = lang === "en" ? "Copied!" : "Tersalin!";
      btn.textContent = copiedText;
      btn.classList.add("copied");
      setTimeout(() => {
        btn.textContent = originalText;
        btn.classList.remove("copied");
      }, 2500);
    }).catch(err => {
      console.error("Clipboard copy failed:", err);
    });
  });
});

const faqItems = document.querySelectorAll(".faq-item");
faqItems.forEach(item => {
  const trigger = item.querySelector(".faq-question");
  if (!trigger) return;

  trigger.addEventListener("click", () => {
    const isOpen = item.classList.contains("open");
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

function applyLang(lang) {
  const d = (window.dict && (window.dict[lang] || window.dict.id)) || {};
  document.documentElement.lang = lang;

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

  for (const attribute of ["alt", "aria-label", "placeholder"]) {
    for (const el of document.querySelectorAll(`[data-i18n-${attribute}]`)) {
      const key = el.getAttribute(`data-i18n-${attribute}`);
      const val = d[key];
      if (val != null) el.setAttribute(attribute, val);
    }
  }

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
      ? "Harmonotch: Prayer times, battery, media controls & AI agent quotas in your MacBook notch"
      : "Harmonotch: Jadwal sholat, baterai, media & kuota AI di notch MacBook";

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc) {
    metaDesc.content =
      lang === "en"
        ? "Astronomical prayer times, battery telemetry & hardware SMC limiter, media playback with lyrics, AI agent quotas, and satellite sliders for macOS."
        : "Jadwal sholat astronomis, status baterai & limiter SMC hardware, media playback dengan lirik, kuota AI Agents, dan satellite sliders untuk macOS.";
  }
}

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

fetchLatestRelease();

const prefersReducedMotion = window.matchMedia(
  "(prefers-reduced-motion: reduce)"
).matches;

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

const revealTargets = document.querySelectorAll(
  ".section-header, .overview-card, .feature-card, .tech-card, .credit-card, " +
    ".install-container, .step-card, .terminal-box, .faq-item, .cta-banner"
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
    { threshold: 0.1, rootMargin: "0px 0px -40px 0px" }
  );

  revealTargets.forEach((el) => {
    const parent = el.parentElement;
    const next = groupIndex.get(parent) || 0;
    el.style.setProperty("--i", Math.min(next, 6));
    groupIndex.set(parent, next + 1);
    el.classList.add("reveal");
    observer.observe(el);
  });
}

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
