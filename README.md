# VerifyFuel - Automated Fuel Management System

A comprehensive fuel management system with mobile app and backend API for managing vehicle fuel distribution with OCR-based verification and smart scheduling.

## Project Structure

```
verifyfuel/
├── frontend/          # Flutter mobile application
│   └── lib/
│       ├── features/  # Feature-based modules
│       ├── core/      # Core utilities and models
│       └── l10n/      # Localization files
├── backend/           # FastAPI backend
│   ├── app/
│   │   ├── models/    # SQLAlchemy models
│   │   ├── schemas/   # Pydantic schemas
│   │   ├── routers/   # API routes
│   │   ├── services/  # Business logic
│   │   └── core/      # Core configuration
│   └── main.py        # FastAPI entry point
```

## Features

- **OCR-based Vehicle Verification**: Scan number plates using Google ML Kit
- **3-Day Eligibility Rule**: Automatic 72-hour waiting period enforcement
- **Smart Scheduling**: Time-slot based fuel distribution
- **Multi-Role Support**: Operators, Vehicle Owners, and Admins
- **Multi-Language**: Bangla (default) and English support
- **Real-time Updates**: Push notifications and status tracking

## Tech Stack

### Frontend
- Flutter
- Riverpod (State Management)
- Google ML Kit (OCR)
- Material Design 3

### Backend
- Python FastAPI
- NeonDB PostgreSQL
- SQLAlchemy
- JWT Authentication

## Getting Started

### Prerequisites
- Flutter SDK
- Python 3.11+
- NeonDB account (free tier: https://neon.tech/)

### Backend Setup

1. **Create NeonDB Database**
   - Sign up at https://neon.tech/
   - Create a new project
   - Copy your connection string

2. **Configure Backend**
   ```bash
   cd backend
   copy .env.example .env
   # Edit .env and paste your NeonDB connection string
   ```

3. **Install Dependencies**
   ```bash
   python -m venv venv
   venv\Scripts\activate  # Windows
   # source venv/bin/activate  # Mac/Linux
   pip install -r requirements.txt
   ```

4. **Run the Backend**
   ```bash
   uvicorn main:app --reload --port 8000
   ```

See `backend/NEONDB_SETUP.md` for detailed instructions.

### Frontend Setup

1. Navigate to frontend directory:
```bash
cd frontend
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Development

### Running Backend Locally
```bash
cd backend
uvicorn main:app --reload --port 8000
```

### Running Frontend
```bash
cd frontend
flutter run
```

### Database Migrations
```bash
cd backend
alembic revision --autogenerate -m "migration message"
alembic upgrade head
```

## API Documentation

Once the backend is running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## License

MIT License
