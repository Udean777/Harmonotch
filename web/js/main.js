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
    console.warn("Could not query GitHub releases API, using default values:", err);
  }
}

for (const a of document.querySelectorAll("a.js-download")) {
  a.setAttribute("href", DL_ENDPOINT);
  a.setAttribute("download", "Harmonotch.dmg");
  a.addEventListener("click", (event) => {
    // Take over the navigation so a failed probe does not start a download
    // and open GitHub at the same time.
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
            ? "Direct download unavailable. Opening the GitHub Releases page."
            : "Unduhan langsung tidak tersedia. Membuka halaman rilis GitHub."
        );
        setTimeout(() => window.open(GITHUB_FALLBACK_URL, "_blank", "noopener"), 1000);
      })
      .catch(() => {
        window.location.href = targetUrl;
      });
  });
}

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

const showcaseTabs = document.querySelectorAll(".showcase-tab");
const mockupDrawers = document.querySelectorAll(".mockup-drawer");
const showcaseInfos = document.querySelectorAll(".showcase-info-pane");

const showcaseVideoWrapper = document.getElementById("showcaseVideoWrapper");
const showcaseVideo = document.getElementById("showcaseVideo");
const videoCenterPlayBtn = document.getElementById("videoCenterPlayBtn");
const videoPlayToggleBtn = document.getElementById("videoPlayToggleBtn");
const videoPlayIcon = document.getElementById("videoPlayIcon");
const videoPlayLabel = document.getElementById("videoPlayLabel");
const videoProgressTrack = document.getElementById("videoProgressTrack");
const videoProgressFill = document.getElementById("videoProgressFill");
const videoRestartBtn = document.getElementById("videoRestartBtn");

const PAUSE_ICON_SVG = `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect></svg>`;
const PLAY_ICON_SVG = `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg>`;

function updateVideoUI(isPlaying) {
  if (!showcaseVideoWrapper) return;
  showcaseVideoWrapper.classList.toggle("is-paused", !isPlaying);
  if (videoPlayIcon) {
    videoPlayIcon.innerHTML = isPlaying ? PAUSE_ICON_SVG : PLAY_ICON_SVG;
  }
  if (videoPlayLabel) {
    const lang = document.documentElement.lang === "en" ? "en" : "id";
    videoPlayLabel.textContent = isPlaying
      ? (lang === "en" ? "Pause" : "Jeda")
      : (lang === "en" ? "Play" : "Putar");
  }
}

function toggleVideoPlayback() {
  if (!showcaseVideo) return;
  if (showcaseVideo.paused || showcaseVideo.ended) {
    showcaseVideo.play().then(() => {
      updateVideoUI(true);
    }).catch(err => {
      console.warn("Video play failed:", err);
      updateVideoUI(false);
    });
  } else {
    showcaseVideo.pause();
    updateVideoUI(false);
  }
}

if (showcaseVideo) {
  const playPromise = showcaseVideo.play();
  if (playPromise !== undefined) {
    playPromise.then(() => {
      updateVideoUI(true);
    }).catch(() => {
      updateVideoUI(false);
    });
  }

  showcaseVideo.addEventListener("play", () => updateVideoUI(true));
  showcaseVideo.addEventListener("pause", () => updateVideoUI(false));
  showcaseVideo.addEventListener("ended", () => updateVideoUI(false));

  showcaseVideo.addEventListener("timeupdate", () => {
    if (!videoProgressFill || !showcaseVideo.duration) return;
    const pct = (showcaseVideo.currentTime / showcaseVideo.duration) * 100;
    videoProgressFill.style.width = `${pct}%`;
    if (videoProgressTrack) {
      videoProgressTrack.setAttribute("aria-valuenow", String(Math.round(pct)));
    }
  });

  if (videoCenterPlayBtn) {
    videoCenterPlayBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      showcaseVideo.play().then(() => updateVideoUI(true)).catch(() => {});
    });
  }

  if (videoPlayToggleBtn) {
    videoPlayToggleBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      toggleVideoPlayback();
    });
  }

  if (videoRestartBtn) {
    videoRestartBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      showcaseVideo.currentTime = 0;
      showcaseVideo.play().then(() => updateVideoUI(true)).catch(() => {});
    });
  }

  if (videoProgressTrack) {
    videoProgressTrack.addEventListener("click", (e) => {
      e.stopPropagation();
      const rect = videoProgressTrack.getBoundingClientRect();
      const clickPos = (e.clientX - rect.left) / rect.width;
      if (showcaseVideo.duration) {
        showcaseVideo.currentTime = clickPos * showcaseVideo.duration;
      }
    });
  }

  if (showcaseVideoWrapper) {
    showcaseVideoWrapper.addEventListener("click", (e) => {
      if (e.target.closest(".video-controls-bar") || e.target.closest(".video-center-play-btn")) return;
      toggleVideoPlayback();
    });
  }
}

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

  if (targetTabId === "video" && showcaseVideo) {
    showcaseVideo.play().then(() => updateVideoUI(true)).catch(() => updateVideoUI(false));
  } else if (targetTabId !== "video" && showcaseVideo) {
    showcaseVideo.pause();
    updateVideoUI(false);
  }
}

showcaseTabs.forEach(tab => {
  tab.addEventListener("click", () => {
    const tabId = tab.getAttribute("data-tab");
    if (tabId) selectShowcaseTab(tabId);
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
      ? "Harmonotch: prayer times, battery, and music in your MacBook notch"
      : "Harmonotch: jadwal sholat, baterai, dan musik di notch MacBook";

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc) {
    metaDesc.content =
      lang === "en"
        ? "Prayer times, battery status, and media controls with synced lyrics in your MacBook notch. Free and open source for macOS 14 and later."
        : "Jadwal sholat, status baterai, dan kontrol musik dengan lirik tersinkron di notch MacBook. Gratis dan open source untuk macOS 14 ke atas.";
  }

  if (showcaseVideo) updateVideoUI(!showcaseVideo.paused);
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
  ".section-header, .showcase-tabs, .mockup-wrapper, " +
    ".showcase-info-container, .feature-card, .install-container, " +
    ".step-card, .terminal-box, .faq-item, .cta-banner"
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
    mockupScreen.style.transform = `perspective(1000px) rotateY(${x * 3}deg) rotateX(${-y * 2.5}deg)`;
  });
  mockup.addEventListener("pointerleave", () => {
    mockupScreen.style.transform = "perspective(1000px) rotateY(0deg) rotateX(0deg)";
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
