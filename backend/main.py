from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, vehicles, fuel
from app.core.database import engine, Base

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="VerifyFuel API",
    description="Automated Fuel Management System Backend",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(vehicles.router)
app.include_router(fuel.router)

@app.get("/")
async def root():
    return {
        "message": "VerifyFuel API is running",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.head("/")
async def root_head():
    return Response(status_code=200)

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
