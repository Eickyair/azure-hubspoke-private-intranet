import os
from azure.storage.blob import BlobServiceClient
from core.config import settings

class StorageService:
    def __init__(self):
        self.use_mock = settings.use_mock_storage
        self.mock_dir = os.path.join(os.path.dirname(__file__), "..", "mock_storage")
        if self.use_mock:
            os.makedirs(self.mock_dir, exist_ok=True)
        else:
            self.blob_service_client = BlobServiceClient(
                account_url=settings.storage_account_url,
                credential=settings.storage_account_key
            )
            self.container_client = self.blob_service_client.get_container_client(settings.storage_container_name)

    def upload_file(self, file_content: bytes, blob_name: str, content_type: str = "application/octet-stream") -> str:
        if self.use_mock:
            file_path = os.path.join(self.mock_dir, blob_name)
            with open(file_path, "wb") as f:
                f.write(file_content)
            return blob_name
        else:
            blob_client = self.container_client.get_blob_client(blob_name)
            blob_client.upload_blob(file_content, overwrite=True)
            return blob_name

    def get_file_content(self, blob_name: str) -> bytes:
        if self.use_mock:
            file_path = os.path.join(self.mock_dir, blob_name)
            if os.path.exists(file_path):
                with open(file_path, "rb") as f:
                    return f.read()
            return b""
        else:
            blob_client = self.container_client.get_blob_client(blob_name)
            return blob_client.download_blob().readall()

storage_service = StorageService()
