# Social Media Assets

Brand images for sharing the catalog on GitHub and social platforms.

| File | Size | Use |
|---|---|---|
| [social-preview-github.jpg](social-preview-github.jpg) | 1280×640 | **Upload this to GitHub** → Settings → General → Social preview |
| [social-preview-1280x640.png](social-preview-1280x640.png) | 1280×640 | Master PNG (lossless, under GitHub's 1 MB limit) |
| [social-preview-square-github.jpg](social-preview-square-github.jpg) | 1200×1200 | Instagram, Mastodon, LinkedIn square posts |

## GitHub social preview

GitHub has **no public API** for this setting — upload goes through the web UI.

### Option A — one-command script (recommended)

From the repo root:

```bash
npm install playwright
npx playwright install chrome
node scripts/upload-social-preview.mjs
```

A Chrome window opens. Sign in to GitHub if prompted; the script uploads [`social-preview-github.jpg`](social-preview-github.jpg) and saves the session for next time.

### Option B — manual upload

1. Open [repository Settings → General](https://github.com/cemalyilmaz/unit-testing-catalog/settings)
2. Scroll to **Social preview** → **Edit** → **Upload an image…**
3. Choose [`social-preview-github.jpg`](social-preview-github.jpg)

The image appears when someone shares `https://github.com/cemalyilmaz/unit-testing-catalog` on Twitter/X, LinkedIn, Slack, Discord, etc.

## Suggested share copy

**Short**

> Flutter Unit Testing Catalog — GoF-style unit testing patterns for Dart & Flutter, with runnable examples.
> https://github.com/cemalyilmaz/unit-testing-catalog

**With hook**

> Every method call is a message: return a value, change state, or call something else. This catalog names the test pattern for each — 15 chapters, 116 tests.
> https://github.com/cemalyilmaz/unit-testing-catalog
