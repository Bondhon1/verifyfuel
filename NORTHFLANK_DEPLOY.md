# Northflank Deployment for VerifyFuel

Northflank is a better fit than Render here because its current Sandbox tier advertises always-on compute with no sleeping.

## Recommended choice

For your app, Northflank is the best simple option if you want:

- a public backend URL for the APK
- no idle sleep
- GitHub-based deployment
- no VM management

## Can it handle 50 to 60 users at a time?

Yes, likely for this project's current backend shape.

Why this is a reasonable fit:

- your OCR is in the Flutter app, not on the backend
- the backend is mostly auth, CRUD, eligibility checks, and database reads/writes
- the container now starts with `2` Uvicorn workers by default
- Neon handles the database separately

That said, this is still an inference, not a benchmark. Exact capacity depends on traffic patterns, query load, and how many users hit the same endpoint at the same time.

## Files added for deployment

- `backend/Dockerfile`
- `backend/.dockerignore`

Northflank can build directly from the `backend` folder in this monorepo.

## Deploy on Northflank

1. Push the repo to GitHub.
2. In Northflank, create a new service from Git.
3. Select this repository.
4. Set the service root path to `backend`.
5. Choose Dockerfile deployment.
6. Confirm the Dockerfile path is `backend/Dockerfile` if Northflank asks for it.
7. Expose the HTTP port.

## Environment variables

Set these in Northflank:

- `DATABASE_URL`
- `SECRET_KEY`
- `ALGORITHM=HS256`
- `ACCESS_TOKEN_EXPIRE_MINUTES=30`
- `WEB_CONCURRENCY=2`

If your first tests show slow responses under load, increase `WEB_CONCURRENCY` only if your plan has enough CPU and memory.

## Verify deployment

After deployment, Northflank will give you a URL like:

```text
https://your-service-name.run.northflank.app
```

Check:

```text
https://your-service-name.run.northflank.app/health
```

If that returns a healthy response, use that URL in the Flutter app build.

## Build APK for the deployed backend

From the `frontend` folder:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-service-name.run.northflank.app
```

APK output:

```text
frontend/build/app/outputs/flutter-apk/app-release.apk
```

## Notes

- For emulator-only testing, you still do not need Northflank.
- For a real phone or shareable APK, you do need a public backend URL.
- If you want the strongest free always-on option, Oracle Cloud is still the more powerful choice, but it requires manual server setup.
