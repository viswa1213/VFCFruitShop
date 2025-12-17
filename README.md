**FreshNest (Fruit Shop) Overview**
- **Stack:** Flutter (Frontend), Node.js + Express (Backend), MongoDB Atlas
- **Goal:** Mobile-first fruit shop with auth, cart, orders, payments, and media uploads
- **Repo Layout:** `Frontend/` Flutter app, `Backend/` Node API

**Prerequisites**
- **Node.js:** v18+ recommended
- **Flutter:** 3.22+ (Android/iOS/macOS targets enabled)
- **MongoDB Atlas:** connection string for `MONGO_URI`
- **Render (optional):** deploy `Backend` (`BASE_URL` points here)
- **AWS S3 (recommended for uploads):** bucket + credentials to persist images

**Backend Setup (Local)**
- **Environment:** create `Backend/.env`
- **Required vars:**
	- `MONGO_URI`: MongoDB Atlas connection string
	- `PORT`: e.g., `5001`
	- `BASE_URL`: e.g., `http://localhost:5001` (or your Render URL)
	- Optional: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`
	- Optional (S3): `AWS_S3_BUCKET`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BASE_URL`
- **Install & Run:**
```bash
cd Backend
npm install
npm start
# or
node server.js
```
- **Health & Diagnostics:**
	- `GET /api/health` → service status
	- `GET /api/uploads-list` → lists files under `/uploads` on server
	- `GET /uploads/<filename>` → serves uploaded images

**Frontend Setup (Local)**
- **Default API:** The app defaults to `https://vfcbackend.onrender.com`.
- **Override API (dev/local):** use `--dart-define=API_BASE_URL=...`.
```bash
cd Frontend
flutter clean && flutter pub get

# Run pointing to Render
flutter run --dart-define=API_BASE_URL=https://vfcbackend.onrender.com

# Run pointing to local backend (Android emulator loopback)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001

# Run pointing to local backend (iOS simulator/macOS)
flutter run --dart-define=API_BASE_URL=http://localhost:5001
```
- **Build Release:**
```bash
# Android APK
flutter build apk --dart-define=API_BASE_URL=https://vfcbackend.onrender.com

# iOS (requires Xcode setup)
flutter build ios --dart-define=API_BASE_URL=https://vfcbackend.onrender.com
```

**Key Features**
- **Persistent session:** user remains logged in until explicit Logout
- **Splash screen:** branded splash routing to Home/Login based on token
- **Robust images:** cached loading + retries; auto-normalizes emulator/localhost URLs
- **Responsive UI:** conservative fixes for text overflow, price labels, buttons

**Image Reliability: What To Know**
- **Root cause on PaaS:** Deployed containers (e.g., Render) may have ephemeral disks; `/uploads` files can disappear after redeploy.
- **Short-term client mitigations:**
	- Cached network image
	- Retry with scheme swap (http↔https) and host replacement to `BASE_URL`
	- Placeholder during retries, stable error icon after exhaustion
- **Recommended backend solution:** Migrate uploads to durable storage (S3) and update DB URLs.

**Migration & Maintenance Scripts (Backend/scripts)**
- **Dump product images:** list distinct image fields to compare with files.
```bash
cd Backend
MONGO_URI="<your-mongo-uri>" node scripts/list_product_images.js
```
- **Replace emulator URLs in DB:** e.g., `10.0.2.2` → your `BASE_URL`.
```bash
cd Backend
MONGO_URI="<your-mongo-uri>" \
BASE_URL="https://vfcbackend.onrender.com" \
node scripts/replace_emulator_urls.js
```
- **Migrate `/uploads` to S3:** upload files and rewrite records.
```bash
cd Backend
MONGO_URI="<your-mongo-uri>" \
AWS_S3_BUCKET="<bucket>" \
AWS_REGION="<region>" \
AWS_ACCESS_KEY_ID="<key>" \
AWS_SECRET_ACCESS_KEY="<secret>" \
S3_BASE_URL="https://<bucket>.s3.<region>.amazonaws.com" \
node scripts/migrate_uploads_to_s3.js
```

**API Surface (Highlights)**
- `/api/auth` → register/login/logout
- `/api/products` → list/detail
- `/api/orders` → place/view orders
- `/api/user` → profile & avatar
- `/api/payments` → Razorpay integration (if configured)
- `/uploads/*` → static serving of uploaded images
- Diagnostics: `/api/health`, `/api/uploads-list`

**Troubleshooting**
- **Images 404 on device:**
	- Check `GET https://vfcbackend.onrender.com/api/uploads-list` → do filenames exist?
	- If files exist locally but not on Render, migrate to S3 (recommended).
	- If DB URLs point to emulator/localhost, run `replace_emulator_urls.js`.
- **dotenv warning in Flutter:** harmless when `.env` isn’t used client-side; provide API via `--dart-define`.
- **Overflow on small screens:** UI uses `FittedBox`/ellipsis in key spots; report any remaining pages.
- **Point app to Render:**
```bash
flutter run --dart-define=API_BASE_URL=https://vfcbackend.onrender.com
```

**Development Tips**
- Prefer `--dart-define` over hardcoding dev URLs in code.
- Keep `BASE_URL` consistent across environments; avoid mixing ports/hosts.
- Use the diagnostics endpoints to confirm server health and uploads presence.

**Deployment Notes (Render)**
- Set environment:
	- `MONGO_URI`, `BASE_URL=https://vfcbackend.onrender.com`
	- Optional: Razorpay keys, AWS S3 creds if migrating
- Redeploy after backend changes; confirm with:
```bash
curl -v https://vfcbackend.onrender.com/api/health
curl -v https://vfcbackend.onrender.com/api/uploads-list
```

**License**
- Proprietary project. Do not redistribute without permission.
