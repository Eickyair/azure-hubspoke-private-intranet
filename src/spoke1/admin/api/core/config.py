from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    SERVICE_NAME: str = "api-private"
    MYSQL_APP_HOST: str = ""
    MYSQL_APP_DATABASE: str = ""
    MYSQL_APP_USER: str = ""
    MYSQL_APP_PASSWORD: str = ""
    MYSQL_PORT: int = 3306

    STORAGE_ACCOUNT_URL: str = ""
    STORAGE_ACCOUNT_KEY: str = ""
    STORAGE_CONTAINER_NAME: str = "documents"

    @property
    def database_url(self) -> str:
        if self.MYSQL_APP_HOST:
            return f"mysql+pymysql://{self.MYSQL_APP_USER}:{self.MYSQL_APP_PASSWORD}@{self.MYSQL_APP_HOST}:{self.MYSQL_PORT}/{self.MYSQL_APP_DATABASE}"
        return "sqlite:///./local_mock.db"

    @property
    def use_mock_storage(self) -> bool:
        return not self.STORAGE_ACCOUNT_URL or not self.STORAGE_ACCOUNT_KEY

settings = Settings()
