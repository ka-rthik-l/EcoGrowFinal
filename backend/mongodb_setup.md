# MongoDB Atlas Setup Guide

## 1. Create an Account

1. Go to [https://www.mongodb.com/atlas](https://www.mongodb.com/atlas)
2. Click **"Try Free"** and sign up (Google/GitHub/email)
3. Choose the **Free Shared (M0)** tier — no credit card needed

## 2. Create a Cluster

1. After login, click **"Build a Database"**
2. Select **M0 FREE** tier
3. Choose a cloud provider (AWS/GCP/Azure) and region closest to you
4. Name your cluster (e.g., `EcoGrowCluster`)
5. Click **"Create Deployment"**

## 3. Set Up Database Access (User)

1. Go to **Security → Database Access** in the sidebar
2. Click **"Add New Database User"**
3. Choose **Password** authentication
4. Enter a **username** (e.g., `ecogrow_admin`)
5. Enter a **strong password** — ⚠️ **save this, you'll need it for the connection string**
6. Set role to **"Read and write to any database"**
7. Click **"Add User"**

## 4. Set Up Network Access (IP Whitelist)

1. Go to **Security → Network Access**
2. Click **"Add IP Address"**
3. For development, click **"Allow Access from Anywhere"** (`0.0.0.0/0`)
   - ⚠️ For production, restrict to your server's IP only
4. Click **"Confirm"**

## 5. Get Your Connection String

1. Go to **Deployment → Database**
2. Click **"Connect"** on your cluster
3. Choose **"Drivers"**
4. Select **Python** and version **3.12 or later**
5. Copy the connection string — it looks like:

```
mongodb+srv://<username>:<password>@ecogrowcluster.xxxxx.mongodb.net/?retryWrites=true&w=majority
```

6. Replace `<username>` and `<password>` with the credentials from Step 3

## 6. Create Your Database

You don't need to manually create the database — Beanie will auto-create it on first connection. But if you want to:

1. Go to **Deployment → Database → Browse Collections**
2. Click **"Create Database"**
3. Database name: `eco_grow_db`
4. Collection name: `users` (others will be auto-created)

## 7. Update Your Backend Code

Open `main.py` and replace the MongoDB connection string:

```python
# Change this:
client = AsyncIOMotorClient("mongodb://localhost:27017")

# To this (paste your Atlas connection string):
client = AsyncIOMotorClient("mongodb+srv://ecogrow_admin:<password>@ecogrowcluster.xxxxx.mongodb.net/?retryWrites=true&w=majority")
```

Then run:

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## 8. Verify Connection

Once the server starts without errors, visit:

```
http://localhost:8000/docs
```

You should see the Swagger UI with all your endpoints. Try registering a user via `POST /auth/register`.

## Essential Collections (Auto-Created)

| Collection | Purpose |
|---|---|
| `users` | User accounts (email, hashed password) |
| `sensor_readings` | Temperature, humidity, sunlight, pH, EC data |
| `alerts` | Critical/Warning/Info notifications |
