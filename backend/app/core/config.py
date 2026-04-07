import os

from dotenv import load_dotenv

try:
    from pydantic import ConfigDict
    from pydantic_settings import BaseSettings
except ModuleNotFoundError:
    BaseSettings = None
    ConfigDict = None


load_dotenv()


if BaseSettings is not None and ConfigDict is not None:
    class Settings(BaseSettings):
        DATABASE_URL: str
        SECRET_KEY: str
        ALGORITHM: str = "HS256"
        ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

        model_config = ConfigDict(
            env_file=".env",
            extra="ignore",
        )


else:
    class Settings:
        def __init__(self) -> None:
            self.DATABASE_URL = self._require("DATABASE_URL")
            self.SECRET_KEY = self._require("SECRET_KEY")
            self.ALGORITHM = os.getenv("ALGORITHM", "HS256")
            self.ACCESS_TOKEN_EXPIRE_MINUTES = int(
                os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30")
            )

        def _require(self, name: str) -> str:
            value = os.getenv(name)
            if not value:
                raise RuntimeError(f"Missing required environment variable: {name}")
            return value


settings = Settings()
