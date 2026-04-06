# Quick Start Guide

## Prerequisites
- Docker Desktop installed and running
- Flutter SDK installed (for frontend development)

## 1. Start the Backend (Fastest Way)

```bash
# Navigate to project directory
cd f:\tmp\projects\verifyfuel

# Create environment file
copy backend\.env.example backend\.env

# Start PostgreSQL and Backend with Docker
docker-compose up -d

# Check if services are running
docker-compose ps

# View logs
docker-compose logs -f backend
```

The API will be available at:
- **API Base URL:** http://localhost:8000
- **API Documentation:** http://localhost:8000/docs
- **Alternative Docs:** http://localhost:8000/redoc

## 2. Test the Backend API

### Using the Interactive Docs (Easiest)
1. Open http://localhost:8000/docs in your browser
2. Try the endpoints interactively

### Using curl (Command Line)

#### Health Check
```bash
curl http://localhost:8000/health
```

#### Register an Operator
```bash
curl -X POST http://localhost:8000/auth/register ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"operator1\",\"email\":\"operator@verifyfuel.com\",\"password\":\"pass123\",\"role\":\"operator\",\"full_name\":\"Pump Operator\"}"
```

#### Register a Vehicle Owner
```bash
curl -X POST http://localhost:8000/auth/register ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"owner1\",\"email\":\"owner@verifyfuel.com\",\"password\":\"pass123\",\"role\":\"owner\",\"full_name\":\"Vehicle Owner\"}"
```

#### Login (Get Token)
```bash
curl -X POST http://localhost:8000/auth/login ^
  -H "Content-Type: application/x-www-form-urlencoded" ^
  -d "username=operator1&password=pass123"
```

Copy the `access_token` from the response and use it in the following requests:

#### Register a Vehicle (with token)
```bash
curl -X POST http://localhost:8000/vehicles/ ^
  -H "Authorization: Bearer YOUR_TOKEN_HERE" ^
  -H "Content-Type: application/json" ^
  -d "{\"plate_number\":\"DHA-123456\",\"owner_id\":1,\"vehicle_type\":\"Car\",\"make\":\"Toyota\",\"model\":\"Corolla\",\"year\":2020}"
```

#### Check Vehicle Eligibility (with token)
```bash
curl http://localhost:8000/fuel/check-eligibility/DHA-123456 ^
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Record Fuel Entry (with token)
```bash
curl -X POST http://localhost:8000/fuel/entries ^
  -H "Authorization: Bearer YOUR_TOKEN_HERE" ^
  -H "Content-Type: application/json" ^
  -d "{\"vehicle_id\":1,\"operator_id\":1,\"amount_liters\":20,\"fuel_type\":\"Petrol\",\"station_name\":\"Station A\"}"
```

#### Check Eligibility Again (Should be denied now)
```bash
curl http://localhost:8000/fuel/check-eligibility/DHA-123456 ^
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## 3. Run Flutter Frontend

```bash
# Navigate to frontend directory
cd frontend

# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Or run on Chrome (for testing)
flutter run -d chrome
```

## 4. Stop Services

```bash
# Stop Docker services
docker-compose down

# Stop and remove volumes (clean database)
docker-compose down -v
```

## Expected Behavior

### First Fuel Entry
- ✅ Vehicle is eligible
- ✅ Fuel entry is recorded
- ✅ Next eligible date is set (72 hours later)
- ✅ Time slot is assigned

### Second Fuel Entry (within 72 hours)
- ❌ Vehicle is NOT eligible
- ❌ Error message in Bangla and English
- ℹ️ Shows hours remaining until next eligible time

### Third Fuel Entry (after 72 hours)
- ✅ Vehicle is eligible again
- ✅ New fuel entry can be recorded

## Troubleshooting

### Docker Issues
```bash
# Restart services
docker-compose restart

# Rebuild backend image
docker-compose build backend

# View backend logs
docker-compose logs backend

# View PostgreSQL logs
docker-compose logs postgres
```

### Database Issues
```bash
# Connect to PostgreSQL
docker exec -it verifyfuel_postgres psql -U verifyfuel -d verifyfuel_db

# List tables
\dt

# View users
SELECT * FROM users;

# View vehicles
SELECT * FROM vehicles;

# Exit
\q
```

### Flutter Issues
```bash
# Clean build
flutter clean
flutter pub get

# Check doctor
flutter doctor

# Run with verbose
flutter run -v
```

## API Testing with Postman

Import this collection to test all endpoints:

1. Create a new collection in Postman
2. Add environment variables:
   - `base_url`: http://localhost:8000
   - `token`: (will be set after login)

3. Create requests for each endpoint listed above

## Development Workflow

1. **Backend changes:** Edit files in `backend/` → Docker auto-reloads
2. **Frontend changes:** Edit files in `frontend/lib/` → Flutter hot reload
3. **Database changes:** Create Alembic migrations

## Next Steps

After testing the backend:
1. Build authentication screens in Flutter
2. Create operator dashboard with OCR functionality
3. Create owner dashboard to view fuel history
4. Integrate the frontend with the backend API

---

**Need Help?** Check IMPLEMENTATION.md for detailed architecture and status.
