import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    service_name: str = os.getenv("SERVICE_NAME", "catalog-api")
    
    # DB config
    mysql_host: str = os.getenv("MYSQL_APP_HOST", "")
    mysql_user: str = os.getenv("MYSQL_APP_USERNAME", "")
    mysql_password: str = os.getenv("MYSQL_APP_PASSWORD", "")
    mysql_database: str = os.getenv("MYSQL_APP_DATABASE", "catalog_db")
    mysql_port: int = int(os.getenv("MYSQL_PORT", "3306"))
    
    # Storage config
    storage_account_url: str = os.getenv("STORAGE_ACCOUNT_URL", "")
    storage_account_key: str = os.getenv("STORAGE_ACCOUNT_KEY", "")
    storage_container_name: str = os.getenv("STORAGE_CONTAINER_NAME", "catalog")
    
    @property
    def use_mock_storage(self) -> bool:
        return not self.storage_account_url or not self.storage_account_key
    
    @property
    def database_url(self) -> str:
        if self.mysql_host:
            return f"mysql+pymysql://{self.mysql_user}:{self.mysql_password}@{self.mysql_host}:{self.mysql_port}/{self.mysql_database}"
        return "sqlite:///./local_catalog.db"

settings = Settings()
