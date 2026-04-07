# Render Deployment for VerifyFuel

This repository is a monorepo, and Render can deploy only the backend by using the `backend` folder as the root directory.

## What you need for an APK

- For an Android emulator, you can use the local backend and the app will default to `http://10.0.2.2:8000`.
- For a real phone or a shareable APK, you need a public backend URL such as Render.

## Deploy backend to Render

1. Push this repository to GitHub.
2. Sign in to Render and create a new Blueprint or Web Service.
3. Connect the GitHub repository.
4. If you use the included `render.yaml`, Render will detect the backend service automatically.
5. Set these environment variables in Render:
   - `DATABASE_URL`
   - `SECRET_KEY`
   - `ALGORITHM=HS256`
   - `ACCESS_TOKEN_EXPIRE_MINUTES=30`
6. Deploy the service.

After deployment, Render will give you a public URL similar to:

```text
https://verifyfuel-backend.onrender.com
```

Use the health endpoint to confirm it is live:

```text
https://your-render-url.onrender.com/health
```

## Build APK with the Render URL

From the `frontend` directory:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-render-url.onrender.com
```

The APK will be generated at:

```text
frontend/build/app/outputs/flutter-apk/app-release.apk
```

## Local development options

### Android emulator

Run the backend locally:

```bash
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Then run the Flutter app without any extra API setting. It will use `http://10.0.2.2:8000`.

### Real Android phone on same Wi-Fi

Run the backend with:

```bash
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Find your computer's LAN IP, then build or run Flutter with:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

Example:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.15:8000
```
