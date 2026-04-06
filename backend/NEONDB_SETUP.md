# NeonDB Setup Instructions

## Step 1: Create NeonDB Database

1. Go to https://neon.tech/ and sign up (free tier available)
2. Create a new project
3. Copy the connection string from the dashboard

## Step 2: Configure Backend

1. Copy `.env.example` to `.env`:
   ```bash
   cd backend
   copy .env.example .env
   ```

2. Edit `.env` and replace `DATABASE_URL` with your NeonDB connection string:
   ```
   DATABASE_URL=postgresql://username:password@ep-xxxx.region.aws.neon.tech/neondb?sslmode=require
   ```

3. Generate a secure SECRET_KEY:
   ```bash
   # On Windows PowerShell
   -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})
   
   # Or use any random 32-character string
   ```

## Step 3: Install Dependencies

```bash
# Create virtual environment
python -m venv venv

# Activate it
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Mac/Linux

# Install packages
pip install -r requirements.txt
```

## Step 4: Run the Backend

```bash
# Make sure you're in the backend directory with venv activated
cd backend
uvicorn main:app --reload --port 8000
```

The API will be available at: http://localhost:8000

## Step 5: Test

Open http://localhost:8000/docs to see the interactive API documentation.

## NeonDB Connection String Format

```
postgresql://[user]:[password]@[host]/[database]?sslmode=require
```

Example:
```
postgresql://myuser:mypassword@ep-cool-darkness-123456.us-east-2.aws.neon.tech/neondb?sslmode=require
```

**Important**: 
- Always use `?sslmode=require` for NeonDB
- Keep your `.env` file private (it's in .gitignore)
- Never commit your actual credentials to GitHub
