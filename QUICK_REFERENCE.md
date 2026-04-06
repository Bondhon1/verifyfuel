# VerifyFuel - Quick Reference

## 🔗 Important Links

- **GitHub**: https://github.com/Bondhon1/verifyfuel
- **API Docs**: http://localhost:8000/docs (when server running)
- **NeonDB Dashboard**: https://console.neon.tech/

## 🚀 Quick Start

### Start Backend Server
```bash
cd backend
.\venv\Scripts\activate
uvicorn main:app --reload --port 8000
```

### Test API
```bash
# Health check
curl http://localhost:8000/health

# Open docs
start http://localhost:8000/docs
```

## 📋 Test Credentials

### Operator
- Username: `operator1`
- Password: `secure123`
- Email: operator@verifyfuel.com

### Owner
- Username: `owner1`
- Password: `secure123`
- Email: owner@verifyfuel.com

### Test Vehicle
- Plate: `DHA-KA-123456`
- Type: Car (Toyota Corolla 2020)
- Owner: owner1

## 🔑 API Quick Tests

### 1. Register User
```bash
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test1","email":"test@example.com","password":"pass123","role":"operator"}'
```

### 2. Login
```bash
curl -X POST http://localhost:8000/auth/login \
  -d "username=operator1&password=secure123"
```

### 3. Check Eligibility
```bash
curl http://localhost:8000/fuel/check-eligibility/DHA-KA-123456 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## 📊 Current Status

| Component | Status |
|-----------|--------|
| Backend API | ✅ Running |
| NeonDB | ✅ Connected |
| GitHub | ✅ Synced |
| Tests | ✅ All Passing |
| Frontend | ⏳ Pending |

## 🗄️ Database Info

**Connection String**:
```
postgresql://neondb_owner:***@ep-spring-river-an98s0iw-pooler.c-6.us-east-1.aws.neon.tech/neondb?sslmode=require
```

**Tables**:
- `users` - User accounts (operators, owners, admins)
- `vehicles` - Vehicle registrations
- `fuel_entries` - Fuel transaction records

## 🎯 Key Features Working

- ✅ 72-hour eligibility rule
- ✅ Smart scheduling (5 time slots)
- ✅ JWT authentication
- ✅ Role-based access
- ✅ Bangla error messages
- ✅ NeonDB integration

## 📝 Next Steps

1. Build authentication screens (Flutter)
2. Create operator dashboard with OCR
3. Create owner dashboard with history
4. Add Bangla localization files
5. Integrate Google ML Kit

## 🛠️ Useful Commands

```bash
# Check if server is running
curl http://localhost:8000/health

# View logs
Get-Content C:\Users\MSILAP~1\AppData\Local\Temp\copilot-detached-*.log -Tail 20

# Restart server
# (Stop the PowerShell window and run uvicorn command again)

# Push to GitHub
git add .
git commit -m "Your message"
git push

# Install new Python package
pip install package-name
pip freeze > requirements.txt
```

## 📞 Support

**Developer**: MD Sadman Hasin Khan Jahen  
**Contact**: 0199508664  
**GitHub**: https://github.com/Bondhon1/verifyfuel  
**Issues**: https://github.com/Bondhon1/verifyfuel/issues

---

**Last Updated**: 2026-04-06  
**Version**: 1.0.0  
**Phase**: 2/5 Complete (50%)
