# Testing Guide - VerifyFuel

## ✅ What You Can Test Right Now

The backend is fully functional. Here's a step-by-step testing guide.

## Prerequisites
```bash
# Start the backend server
cd backend
venv\Scripts\activate  # Windows
uvicorn main:app --reload --port 8000
```

## Test Sequence

### 1. Health Check
```bash
curl http://localhost:8000/health
```
**Expected Response:**
```json
{"status": "healthy"}
```

### 2. View API Documentation
Open in browser: http://localhost:8000/docs

You'll see all 9 endpoints with interactive testing capability.

### 3. Register an Operator

**Using curl:**
```bash
curl -X POST http://localhost:8000/auth/register -H "Content-Type: application/json" -d "{\"username\":\"operator1\",\"email\":\"op@verifyfuel.com\",\"password\":\"secure123\",\"role\":\"operator\",\"full_name\":\"Pump Operator One\"}"
```

**Using Swagger UI:**
1. Go to http://localhost:8000/docs
2. Click on `POST /auth/register`
3. Click "Try it out"
4. Enter:
```json
{
  "username": "operator1",
  "email": "op@verifyfuel.com",
  "phone": "01995086644",
  "full_name": "Pump Operator One",
  "role": "operator",
  "password": "secure123"
}
```
5. Click "Execute"

**Expected Response:** User object with ID=1

### 4. Register a Vehicle Owner

```bash
curl -X POST http://localhost:8000/auth/register -H "Content-Type: application/json" -d "{\"username\":\"owner1\",\"email\":\"owner@verifyfuel.com\",\"password\":\"secure123\",\"role\":\"owner\",\"full_name\":\"Vehicle Owner One\"}"
```

**Expected Response:** User object with ID=2

### 5. Login as Operator

```bash
curl -X POST http://localhost:8000/auth/login -H "Content-Type: application/x-www-form-urlencoded" -d "username=operator1&password=secure123"
```

**Expected Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

**IMPORTANT:** Copy the `access_token` value. You'll use it for authenticated requests.

### 6. Register a Vehicle

Replace `YOUR_TOKEN` with the token from step 5:

```bash
curl -X POST http://localhost:8000/vehicles/ -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"plate_number\":\"DHA-KA-123456\",\"owner_id\":2,\"vehicle_type\":\"Car\",\"make\":\"Toyota\",\"model\":\"Corolla\",\"year\":2020}"
```

**Expected Response:** Vehicle object with ID=1

### 7. Check Vehicle Eligibility (First Time)

```bash
curl http://localhost:8000/fuel/check-eligibility/DHA-KA-123456 -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Response:**
```json
{
  "is_eligible": true,
  "message": "অনুমোদিত - প্রথম জ্বালানি প্রবেশ - Approved: First fuel entry",
  "plate_number": "DHA-KA-123456",
  "last_fuel_date": null,
  "next_eligible_date": null,
  "next_slot_start": null,
  "next_slot_end": null,
  "hours_remaining": null
}
```

✅ **Vehicle is eligible for fuel!**

### 8. Record First Fuel Entry

```bash
curl -X POST http://localhost:8000/fuel/entries -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"vehicle_id\":1,\"operator_id\":1,\"amount_liters\":20,\"fuel_type\":\"Petrol\",\"station_name\":\"Main Station\"}"
```

**Expected Response:** Fuel entry with:
- `entry_datetime`: Current time
- `next_eligible_date`: 72 hours from now
- `next_slot_start`: Scheduled slot start time
- `next_slot_end`: Scheduled slot end time

### 9. Check Eligibility Again (Should be DENIED)

```bash
curl http://localhost:8000/fuel/check-eligibility/DHA-KA-123456 -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Response:**
```json
{
  "is_eligible": false,
  "message": "অস্বীকৃত - এখনও 72 ঘন্টা বাকি - Denied: 72 hours remaining",
  "plate_number": "DHA-KA-123456",
  "last_fuel_date": "2026-04-06T15:XX:XX",
  "next_eligible_date": "2026-04-09T15:XX:XX",
  "next_slot_start": "2026-04-09T15:00:00",
  "next_slot_end": "2026-04-09T18:00:00",
  "hours_remaining": 72
}
```

❌ **Vehicle is NOT eligible - must wait 72 hours!**

### 10. Try to Record Fuel Again (Should FAIL)

```bash
curl -X POST http://localhost:8000/fuel/entries -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"vehicle_id\":1,\"operator_id\":1,\"amount_liters\":20,\"fuel_type\":\"Petrol\"}"
```

**Expected Response:** HTTP 400 Bad Request with Bangla error message

### 11. View Fuel History

```bash
curl http://localhost:8000/fuel/entries/1 -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Response:** Array with one fuel entry

### 12. Register Another Vehicle & Test

```bash
# Register second vehicle
curl -X POST http://localhost:8000/vehicles/ -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"plate_number\":\"CTG-CH-789012\",\"owner_id\":2,\"vehicle_type\":\"Motorcycle\",\"make\":\"Honda\",\"model\":\"CBR\"}"

# Check eligibility (should be approved - first time)
curl http://localhost:8000/fuel/check-eligibility/CTG-CH-789012 -H "Authorization: Bearer YOUR_TOKEN"

# Record fuel
curl -X POST http://localhost:8000/fuel/entries -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"vehicle_id\":2,\"operator_id\":1,\"amount_liters\":10,\"fuel_type\":\"Petrol\"}"
```

## Test Cases to Verify

### ✅ Test Case 1: First-Time Vehicle
- Register vehicle
- Check eligibility → Should be **approved**
- Record fuel entry → Should **succeed**
- Check again → Should be **denied** for 72 hours

### ✅ Test Case 2: 72-Hour Rule
- Vehicle with recent fuel entry
- Check eligibility → Should be **denied**
- Response should show hours remaining
- Response should show next eligible date and slot

### ✅ Test Case 3: Multiple Vehicles
- Different vehicles can get fuel independently
- Each vehicle has its own 72-hour timer
- Plate numbers must be unique

### ✅ Test Case 4: Role-Based Access
- Owners can view only their vehicles
- Operators can view all vehicles
- Only operators can record fuel entries

### ✅ Test Case 5: Smart Scheduling
- Fuel entry at 10 AM → Next slot should be 9 AM - 12 PM (after 3 days)
- Fuel entry at 2 PM → Next slot should be 12 PM - 3 PM (after 3 days)
- Fuel entry at 7 PM → Next slot should be 6 PM - 9 PM (after 3 days)

## Database Inspection

### Connect to NeonDB
You can use any PostgreSQL client to connect to your NeonDB database:

**Connection Details from .env:**
```
DATABASE_URL=postgresql://username:password@ep-xxxx.region.aws.neon.tech/neondb?sslmode=require
```

**Using psql (if installed):**
```bash
psql "postgresql://username:password@ep-xxxx.region.aws.neon.tech/neondb?sslmode=require"
```

**Or use NeonDB Console:**
- Visit https://console.neon.tech/
- Navigate to your project
- Use the SQL Editor

### Check Data
```sql
-- View all users
SELECT id, username, role, email FROM users;

-- View all vehicles
SELECT id, plate_number, owner_id, vehicle_type FROM vehicles;

-- View fuel entries with details
SELECT 
    fe.id,
    v.plate_number,
    fe.amount_liters,
    fe.entry_datetime,
    fe.next_eligible_date,
    fe.next_slot_start,
    fe.next_slot_end
FROM fuel_entries fe
JOIN vehicles v ON fe.vehicle_id = v.id
ORDER BY fe.entry_datetime DESC;

-- Exit PostgreSQL
\q
```

## Expected Behaviors

### ✅ Correct Behaviors
1. First fuel entry for any vehicle → **Approved**
2. Second entry within 72 hours → **Denied with Bangla message**
3. Token required for all protected endpoints
4. Plate numbers are unique across system
5. Each vehicle has independent 72-hour timer
6. Time slots assigned based on current time
7. Next eligible date is exactly 72 hours from entry

### ❌ Should NOT Happen
1. Same vehicle getting fuel twice within 72 hours
2. Access without valid token
3. Owners accessing other owners' vehicles
4. Non-operators creating fuel entries
5. Duplicate plate numbers

## Cleanup & Reset

### Reset Database (Start Fresh)
To reset the database, you can:
1. Drop all tables from NeonDB Console
2. Or create a new NeonDB database
3. Update your `.env` with the new connection string
4. Restart the backend server - tables will be recreated automatically

### View Logs
```bash
# Backend logs are shown in the terminal where uvicorn is running
# Or redirect output to a file:
uvicorn main:app --reload --port 8000 > backend.log 2>&1
```

## Next: Frontend Testing

Once Phase 3 is complete, you'll be able to:
- Login through mobile app
- Scan number plates with camera
- See eligibility status on screen
- Record fuel entries with tap
- View fuel history
- See countdown timer for next fuel

---

**Current Status**: Backend fully functional and ready for testing! 🎉  
**Start**: `uvicorn main:app --reload --port 8000` → http://localhost:8000/docs
