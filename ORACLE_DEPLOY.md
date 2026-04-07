# Oracle Cloud Free Tier Deployment

This project can run on an Oracle Cloud Always Free VM alongside Render. For your backend shape, Oracle is the stronger free option because Oracle documents Always Free Ampere A1 capacity equivalent to up to `4 OCPUs` and `24 GB` memory total in the home region.

Source:
- https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm

## Before you start

You need:

- an Oracle Cloud account with Always Free enabled
- your home region selected carefully
- a GitHub copy of this repository
- your Neon database connection string
- an SSH key pair on your computer

Important:

- Always Free resources are limited by region availability
- your chosen home region matters because Always Free capacity is tied to it
- Oracle sometimes shows `Out of capacity` for Ampere instances, so you may need to retry or choose a different availability domain

## Step 1: Create an SSH key pair

If you already have a key, you can reuse it. On Windows PowerShell:

```powershell
ssh-keygen -t ed25519 -C "verifyfuel-oracle"
```

Default path is usually:

```text
C:\Users\YOUR_USER\.ssh\id_ed25519
```

Your public key will be:

```text
C:\Users\YOUR_USER\.ssh\id_ed25519.pub
```

Open that `.pub` file and copy the full contents. Oracle will ask for it when creating the VM.

## Step 2: Create the Oracle VM

In the Oracle Cloud console:

1. Open `Compute`
2. Open `Instances`
3. Click `Create instance`
4. Name it something like `verifyfuel-api`
5. Keep the default compartment unless you use your own
6. For image, choose `Ubuntu 22.04` or `Ubuntu 24.04`
7. For shape, click `Change shape`
8. Select `Ampere`
9. Choose `VM.Standard.A1.Flex`
10. Start with `2 OCPUs` and `6 GB` memory
11. In the networking section, keep or create a public subnet with a public IPv4 address
12. In the SSH keys section, paste your public key
13. Create the instance

If `VM.Standard.A1.Flex` is unavailable due to capacity:

- retry later
- try a different availability domain
- fall back to a smaller Ampere configuration first, then resize later

## Step 3: Open web ports in Oracle networking

Oracle's default VCN security list often allows SSH on port `22`, but web traffic ports need to be added explicitly.

Sources:
- https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securitylists.htm
- https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securityrules.htm

In the Oracle console:

1. Open your instance
2. Open the subnet or VCN details linked from the instance
3. Open `Security Lists` or `Network Security Groups`
4. Add ingress rules for:
   - TCP `80` from `0.0.0.0/0`
   - TCP `443` from `0.0.0.0/0`
   - TCP `22` from your own public IP if possible

If you are using Ubuntu firewall locally on the VM, also allow Nginx:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

## Step 4: Connect to the VM

From your computer:

```bash
ssh ubuntu@YOUR_PUBLIC_IP
```

If Oracle used a different default user in your image, the console will show it, but Ubuntu images usually use `ubuntu`.

## Step 5: Install system packages

Run:

```bash
sudo apt update
sudo apt install -y python3.11-venv python3-pip nginx git
```

Optional but helpful:

```bash
sudo apt install -y unzip htop
```

## Step 6: Clone the repo on the VM

```bash
sudo mkdir -p /opt/verifyfuel
sudo chown -R $USER:$USER /opt/verifyfuel
git clone https://github.com/Bondhon1/verifyfuel.git /opt/verifyfuel
cd /opt/verifyfuel/backend
```

If the repo already exists and you want updates later:

```bash
cd /opt/verifyfuel
git pull origin main
cd backend
```

## Step 7: Create the Python environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## Step 8: Configure environment variables

Create the runtime env file:

```bash
cp .env.example .env
nano .env
```

Set:

- `DATABASE_URL`
- `SECRET_KEY`
- `ALGORITHM=HS256`
- `ACCESS_TOKEN_EXPIRE_MINUTES=30`

Example:

```env
DATABASE_URL=postgresql://username:password@host/neondb?sslmode=require
SECRET_KEY=replace-with-a-new-secret
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

Generate a fresh secret if needed:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

## Step 9: Test the backend manually first

Before setting up `systemd`, make sure the app runs:

```bash
source /opt/verifyfuel/backend/venv/bin/activate
cd /opt/verifyfuel/backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

In another SSH session:

```bash
curl http://127.0.0.1:8000/health
```

You should get:

```json
{"status":"healthy"}
```

Stop the temporary server with `Ctrl+C` after this passes.

## Step 10: Install the systemd service

This repo includes a service template:
- [verifyfuel.service](/f:/tmp/projects/verifyfuel/backend/deploy/verifyfuel.service)

Install it:

```bash
sudo cp /opt/verifyfuel/backend/deploy/verifyfuel.service /etc/systemd/system/verifyfuel.service
sudo systemctl daemon-reload
sudo systemctl enable verifyfuel
sudo systemctl start verifyfuel
sudo systemctl status verifyfuel
```

Useful commands:

```bash
sudo systemctl restart verifyfuel
sudo journalctl -u verifyfuel -n 100 --no-pager
sudo journalctl -u verifyfuel -f
```

Health check locally:

```bash
curl http://127.0.0.1:8000/health
```

## Step 11: Put Nginx in front of FastAPI

This repo includes an Nginx config template:
- [verifyfuel.nginx.conf](/f:/tmp/projects/verifyfuel/backend/deploy/verifyfuel.nginx.conf)

Install it:

```bash
sudo cp /opt/verifyfuel/backend/deploy/verifyfuel.nginx.conf /etc/nginx/sites-available/verifyfuel
sudo ln -s /etc/nginx/sites-available/verifyfuel /etc/nginx/sites-enabled/verifyfuel
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

Public check:

```bash
curl http://YOUR_PUBLIC_IP/health
```

If that works, the backend is publicly reachable.

## Step 12: Optional domain and HTTPS

If you later add a domain:

1. Create an `A` record pointing `api.yourdomain.com` to the Oracle VM public IP
2. Wait for DNS propagation
3. Install TLS with Certbot

Commands:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.yourdomain.com
```

Then verify:

```bash
curl https://api.yourdomain.com/health
```

## Step 13: Build the APK against Oracle

Once the Oracle backend is reachable, build the APK with:

```bash
cd frontend
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_PUBLIC_IP
```

If you add HTTPS and a domain:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

## Updating the Oracle deployment later

When you change backend code:

```bash
ssh ubuntu@YOUR_PUBLIC_IP
cd /opt/verifyfuel
git pull origin main
cd backend
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart verifyfuel
```

## Troubleshooting

### SSH does not connect

- confirm the instance has a public IP
- confirm port `22` is open in Oracle networking
- confirm you used the correct private key

### `curl http://127.0.0.1:8000/health` fails

- check `sudo systemctl status verifyfuel`
- check `sudo journalctl -u verifyfuel -n 100 --no-pager`
- confirm `/opt/verifyfuel/backend/.env` exists and is valid

### Public IP does not respond

- confirm Oracle ingress rules allow port `80`
- check Nginx with `sudo systemctl status nginx`
- test Nginx config with `sudo nginx -t`

### App starts but database calls fail

- verify `DATABASE_URL`
- ensure it includes `?sslmode=require` for Neon
- verify the Neon database is reachable from the internet

## Notes

- Render is easier to deploy.
- Oracle Free Tier is stronger for always-on capacity.
- Capacity still depends on actual query patterns and database latency, so treat 50 to 60 concurrent users as a target to test, not a guarantee.
- Rotate your current database password and secret key after deployment if they were exposed outside your machine.
