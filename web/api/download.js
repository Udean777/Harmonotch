/**
 * Vercel Serverless Function - Proxy download DMG installer dari GitHub Releases.
 * Mengikuti penamaan rilis CI/CD Harmonotch-${version}.dmg (misal Harmonotch-1.1.1.dmg).
 * 
 * Fitur:
 * - Menetapkan header Content-Disposition dengan nama file rilis asli (Harmonotch-${version}.dmg)
 * - Mencegah isu unduhan Chrome macet 100% dengan streaming & Content-Length
 * - Mendukung query param ?file=Harmonotch-X.X.X.dmg & ?tag=vX.X.X dari client sebagai fallback hint
 * - Fallback cerdas ke laman GitHub Releases jika API rate-limited
 */

const REPO_OWNER = "Udean777";
const REPO_NAME = "Harmonotch";
const RELEASES_PAGE_URL = `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest`;

async function getLatestDmgDownloadUrl(requestedFile, requestedTag) {
  // 1. Coba deteksi via GitHub Releases API
  try {
    const res = await fetch(`https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`, {
      headers: {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Harmonotch-Web-Downloader"
      }
    });

    if (res.ok) {
      const data = await res.json();
      if (data.assets && Array.isArray(data.assets)) {
        // Cari aset .dmg yang dihasilkan workflow release CI/CD (Harmonotch-*.dmg)
        const versionedDmg = data.assets.find(a => a.name && a.name.endsWith(".dmg"));
        if (versionedDmg && versionedDmg.browser_download_url) {
          return {
            url: versionedDmg.browser_download_url,
            name: versionedDmg.name,
            size: versionedDmg.size
          };
        }
      }
    }
  } catch (err) {
    console.error("Failed to query GitHub Releases API:", err);
  }

  // 2. Jika API rate-limited namun client mengirim hint nama file dan tag
  if (requestedFile && requestedFile.endsWith(".dmg")) {
    const directUrl = requestedTag
      ? `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${requestedTag}/${requestedFile}`
      : `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest/download/${requestedFile}`;
    return { url: directUrl, name: requestedFile, size: null };
  }

  // 3. Fallback umum: arahkan ke halaman release GitHub
  return { url: RELEASES_PAGE_URL, name: null, size: null, isFallbackPage: true };
}

export default async function handler(req, res) {
  if (req.method !== "GET" && req.method !== "HEAD") {
    res.setHeader("Allow", "GET, HEAD");
    return res.status(405).json({ error: "Method not allowed" });
  }

  // Ekstrak query parameters jika ada
  let requestedFile = null;
  let requestedTag = null;
  try {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    requestedFile = url.searchParams.get("file");
    requestedTag = url.searchParams.get("tag");
  } catch {}

  const releaseAsset = await getLatestDmgDownloadUrl(requestedFile, requestedTag);

  // Jika tidak ditemukan aset spesifik, redirect ke halaman release GitHub
  if (releaseAsset.isFallbackPage || !releaseAsset.name) {
    return res.redirect(302, RELEASES_PAGE_URL);
  }

  const { url: downloadUrl, name: fileName, size: knownSize } = releaseAsset;

  // HEAD method: cek ketersediaan tanpa stream body
  if (req.method === "HEAD") {
    try {
      const head = await fetch(downloadUrl, { method: "HEAD", redirect: "follow" });
      res.setHeader("Content-Type", "application/x-apple-diskimage");
      res.setHeader("Content-Disposition", `attachment; filename="${fileName}"`);
      const len = head.headers.get("content-length") || (knownSize ? String(knownSize) : null);
      if (len) res.setHeader("Content-Length", len);
      res.setHeader("Cache-Control", "public, max-age=300, s-maxage=300");
      return res.status(head.ok ? 200 : 302).end();
    } catch {
      return res.redirect(302, downloadUrl);
    }
  }

  // GET method: Stream DMG langsung ke client dengan nama file versi rilis
  try {
    const ghRes = await fetch(downloadUrl, { redirect: "follow" });
    if (!ghRes.ok || !ghRes.body) {
      return res.redirect(302, downloadUrl);
    }

    res.setHeader("Content-Type", "application/x-apple-diskimage");
    res.setHeader("Content-Disposition", `attachment; filename="${fileName}"`);
    const len = ghRes.headers.get("content-length") || (knownSize ? String(knownSize) : null);
    if (len) res.setHeader("Content-Length", len);
    res.setHeader("Cache-Control", "public, max-age=300, s-maxage=300");

    const reader = ghRes.body.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      res.write(value);
    }
    res.end();
  } catch (err) {
    console.error("Stream error in /api/download:", err);
    // Headers are already sent once streaming starts; redirecting now throws.
    if (res.headersSent) {
      return res.end();
    }
    return res.redirect(302, downloadUrl || RELEASES_PAGE_URL);
  }
}
