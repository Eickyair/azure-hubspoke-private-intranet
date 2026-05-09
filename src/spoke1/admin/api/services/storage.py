from typing import Optional
from core.config import settings
import os
from azure.storage.blob import BlobServiceClient

class StorageService:
    def __init__(self):
        self.use_mock = settings.use_mock_storage
        self.mock_dir = "./mock_storage"
        if self.use_mock and not os.path.exists(self.mock_dir):
            os.makedirs(self.mock_dir)

    def get_blob_url(self, blob_name: str) -> Optional[str]:
        if not blob_name:
            return None
        # Devuelve una ruta de proxy interna de la API
        return f"/api/storage/{blob_name}"

    def get_file_content(self, blob_name: str) -> bytes:
        if self.use_mock:
            filepath = os.path.join(self.mock_dir, blob_name)
            if os.path.exists(filepath):
                with open(filepath, "rb") as f:
                    return f.read()
            # Si no existe, creamos un archivo dummy para simular el mock
            dummy_content = f"Mock content for {blob_name}".encode('utf-8')
            with open(filepath, "wb") as f:
                f.write(dummy_content)
            return dummy_content
            
        client = BlobServiceClient(account_url=settings.STORAGE_ACCOUNT_URL, credential=settings.STORAGE_ACCOUNT_KEY)
        blob_client = client.get_blob_client(container=settings.STORAGE_CONTAINER_NAME, blob=blob_name)
        return blob_client.download_blob().readall()

    def upload_file(self, file_content: bytes, blob_name: str, content_type: str = "application/octet-stream") -> str:
        if self.use_mock:
            filepath = os.path.join(self.mock_dir, blob_name)
            with open(filepath, "wb") as f:
                f.write(file_content)
            return blob_name
            
        client = BlobServiceClient(account_url=settings.STORAGE_ACCOUNT_URL, credential=settings.STORAGE_ACCOUNT_KEY)
        blob_client = client.get_blob_client(container=settings.STORAGE_CONTAINER_NAME, blob=blob_name)
        blob_client.upload_blob(file_content, overwrite=True)
        return blob_name

storage_service = StorageService()
