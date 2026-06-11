# Codebase & CI/CD Workflow

## Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Next.js (App Router) | ^15.5.18 |
| Language | TypeScript | ^5 |
| Styling | Tailwind CSS | ^4 |
| Animation | Framer Motion (`motion/react`) | — |
| Icons | Remix Icon (`@remixicon/react`) | — |
| Package Manager | pnpm | v10 |
| Node.js | 20 | — |
| Web Server (prod) | Apache HTTPD | 2.4.67 |

---

## Project Structure

```
/
├── src/
│   ├── app/
│   │   ├── layout.tsx          # Root layout — sets metadata, fonts
│   │   └── page.tsx            # Home page — composes all sections
│   └── components/
│       ├── Fade.tsx            # Framer Motion fade-in animation wrappers
│       ├── Navbar.tsx          # Responsive sticky navbar with scroll effect
│       └── ui/
│           ├── Hero.tsx        # Hero section with Game-of-Life canvas background
│           ├── HeroBackground.tsx  # Canvas animation ("use client")
│           ├── Features.tsx    # Product features grid
│           ├── Testimonial.tsx # Customer quote with images
│           ├── Map/
│           │   └── Map.tsx     # Interactive map component
│           ├── CallToAction.tsx # CTA section with farm imagery
│           └── Footer.tsx      # Site footer
├── public/
│   └── images/                 # Static images (synced to S3 on deploy)
│       ├── clouds.png
│       ├── drone.png
│       ├── farm-footer.webp
│       ├── field.png
│       └── smiller.jpeg
├── next.config.ts              # Next.js configuration
├── eslint.config.mjs           # ESLint v9 flat config
├── tailwind.config.ts
├── tsconfig.json
├── package.json
├── pnpm-lock.yaml
└── .github/
    └── workflows/
        ├── code-quality.yml    # Lint + typecheck + format
        ├── security.yml        # Dependency audit + secret scan
        ├── deploy-s3-assets.yml # Build → S3 → EC2 → (CF cache safe by design)
        └── auto-pr.yml         # Auto-create PRs across branches
```

---

## `next.config.ts`

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",       // Produces a static out/ directory (no Node.js server)
  images: { unoptimized: true }, // Disables next/image optimization API
};

export default nextConfig;
```

**`output: "export"`** — Next.js builds a completely static site into the `out/` directory. Every page is rendered to an `.html` file at build time. This output is served directly by Apache on EC2 with no Node.js process required.

**`images: { unoptimized: true }`** — Next.js's default image optimization API (`/_next/image?url=...`) requires a running server to resize images on demand. In static export mode there is no server, so this flag makes `<Image>` components emit plain `<img src="/images/file.jpg">` tags that Apache serves directly.

---

## Key Components

### `Fade.tsx` — Animation System

All hero text and section entries use Framer Motion wrappers. The static HTML is server-rendered with `opacity: 0; filter: blur(4px); transform: translateY(16px)` baked in. When JavaScript loads and React hydrates, Framer Motion animates each child to `opacity: 1` with a spring transition.

```tsx
// FadeContainer triggers the stagger sequence
<motion.div variants={container} initial="hidden" animate="show">
  <FadeSpan>Autonomy</FadeSpan>  // opacity: 0 → 1, blur 4px → 0
  <FadeSpan>for every Farm</FadeSpan>
</motion.div>
```

### `HeroBackground.tsx` — Canvas Animation

A `"use client"` component that renders a Conway's Game of Life simulation on a `<canvas>` element. It runs client-side only, initialised in `useEffect`. The canvas is positioned absolutely behind the hero text using `-z-10`. The background fill color is `#F9FAFB` (Tailwind `gray-50`).

### `Navbar.tsx`

Sticky navbar with a scroll event listener. Below the fold it gains a backdrop blur and border. On mobile it collapses to a hamburger menu. The `"Get a quote"` button was removed in a previous commit per design decision.

---

## CI/CD Workflows

### 1. `code-quality.yml` — Code Quality

**Trigger:** Every push and pull request to any branch.

**Jobs:**

| Job | Command | What it checks |
|-----|---------|----------------|
| `lint` | `pnpm eslint .` | ESLint v9 flat config (`eslint.config.mjs`) |
| `type-check` | `pnpm tsc --noEmit` | TypeScript type safety |
| `format` | `pnpm prettier --check "src/**/*.{ts,tsx,css}" "*.{ts,mjs,json}"` | Consistent formatting |

All three must pass before a PR can merge to `main` (enforced by branch protection rules).

**ESLint config** (`eslint.config.mjs`):
```js
import { FlatCompat } from "@eslint/eslintrc";
const compat = new FlatCompat({ baseDirectory: __dirname });
export default [
  { ignores: [".next/**", "node_modules/**", "next-env.d.ts"] },
  ...compat.extends("next/core-web-vitals", "next/typescript"),
];
```

---

### 2. `security.yml` — Security Scanning

**Trigger:** Pull requests to `main` or `staging`; weekly cron (Mondays 09:00 UTC).

**Jobs:**

| Job | Tool | What it checks |
|-----|------|----------------|
| `audit` | `pnpm audit --prod --audit-level=high` | High/critical CVEs in production dependencies |
| `dependency-review` | `actions/dependency-review-action@v4` | New vulnerable packages introduced by the PR |
| `secret-scan` | `trufflesecurity/trufflehog@main --only-verified` | Verified secrets accidentally committed to the repo |

`--prod` flag on audit skips dev-tool vulnerabilities (ESLint, TypeScript, etc.) that have no runtime impact. `--only-verified` on TruffleHog reduces false positives — it only flags credentials that are confirmed live against the target service.

**pnpm overrides** in `package.json` pin transitive dependencies to patched versions:
```json
"pnpm": {
  "overrides": {
    "tar": ">=7.5.11",
    "minimatch@<3.1.4": "^3.1.4",
    "flatted": ">=3.4.2",
    "picomatch@<2.3.2": "^2.3.2"
  }
}
```

---

### 3. `deploy-s3-assets.yml` — Build & Deploy

**Trigger:** Push to `main` only.

**Full pipeline:**

```
Checkout → pnpm install → pnpm build → Configure AWS → Upload to S3 → SSM sync EC2s
```

#### Step 1: Build

```bash
pnpm build
# Produces: out/
#   out/index.html
#   out/_next/static/chunks/*.js    (content-hashed)
#   out/_next/static/css/*.css      (content-hashed)
#   out/images/*.{png,webp,jpeg}
```

#### Step 2: Upload to S3

Two separate sync passes with different cache headers:

```bash
# Hashed JS/CSS — safe to cache for 1 year
aws s3 sync out/_next/ s3://bucket/frontend/_next/ \
  --delete \
  --cache-control "public, max-age=31536000, immutable" \
  --sse AES256

# HTML and images — always revalidate
aws s3 sync out/ s3://bucket/frontend/ \
  --delete --exclude "_next/*" \
  --cache-control "public, max-age=0, must-revalidate" \
  --sse AES256
```

`--delete` removes files from S3 that no longer exist in `out/`, preventing stale chunks from accumulating. `--sse AES256` satisfies the bucket's `DenyUnencryptedUploads` policy.

#### Step 3: SSM sync to EC2

```bash
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --instance-ids $INSTANCE_IDS \
  --parameters 'commands=[
    "aws s3 sync s3://bucket/frontend/ /var/www/html/ --delete --exact-timestamps --region us-east-1",
    "systemctl restart httpd"
  ]'
```

`--exact-timestamps` forces re-download whenever the S3 object is newer than the local file, even if file sizes match. This prevents a known issue where rebuilt HTML (same size, new content) would be skipped by the default size-based comparison.

The workflow waits for each instance to complete and checks the `Status` field. Any non-`Success` status fails the workflow and prints stderr from the remote command.

#### CloudFront Cache

No explicit invalidation step is needed because:
- **JS/CSS:** Content-hashed filenames — a new build produces new URLs. Old cached URLs still point to old (but valid) files; new HTML references new URLs.
- **HTML:** `max-age=0, must-revalidate` — CloudFront always revalidates HTML from the origin. Users see new HTML on the next request.

---

### 4. `auto-pr.yml` — Automated Pull Requests

Automatically creates pull requests when branches are pushed, routing changes through:

```
feature branches → staging → main
```

---

## Deployment Architecture: Why Static Export?

The app is deployed as a static export rather than a Next.js standalone server because:

1. **No dynamic routes** — all pages are statically renderable at build time
2. **Apache on EC2** — the EC2 instances run Apache, not Node.js; a standalone Next.js server would require Node.js and a process manager (PM2, systemd unit) on each instance
3. **S3 + CloudFront** — static files are a natural fit for S3 (unlimited storage, durable, cheap) fronted by CloudFront (global CDN, immutable JS/CSS cached at edge)
4. **Simpler operations** — Apache serves flat files with no process management, no memory leaks, no application crashes

The trade-off is no server-side rendering on demand and no API routes — acceptable for this marketing/product site.
