import base64
import os
import sys
from dataclasses import dataclass
from typing import Iterable

import pymysql
import requests
from azure.core.exceptions import ResourceExistsError
from azure.storage.blob import BlobServiceClient, ContentSettings


PRODUCT_SKUS = [
    "NW-ELEC-001",
    "NW-ELEC-002",
    "NW-OFFI-001",
    "NW-OFFI-002",
    "NW-CLEAN-001",
]


@dataclass(frozen=True)
class Settings:
    storage_account_url: str
    storage_account_key: str
    storage_container_name: str
    mysql_host: str
    mysql_database: str
    mysql_user: str
    mysql_password: str
    image_urls: list[str]


def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def required_env_b64(name: str) -> str:
    return base64.b64decode(required_env(name)).decode("utf-8")


def load_settings() -> Settings:
    image_urls_text = required_env_b64("POSTDEPLOY_IMAGE_URLS_B64")
    image_urls = [line.strip() for line in image_urls_text.splitlines() if line.strip()]
    if not image_urls:
        raise RuntimeError("No image URLs were provided.")

    return Settings(
        storage_account_url=required_env_b64("POSTDEPLOY_STORAGE_ACCOUNT_URL_B64"),
        storage_account_key=required_env_b64("POSTDEPLOY_STORAGE_ACCOUNT_KEY_B64"),
        storage_container_name=required_env_b64("POSTDEPLOY_STORAGE_CONTAINER_B64"),
        mysql_host=required_env_b64("POSTDEPLOY_MYSQL_HOST_B64"),
        mysql_database=required_env_b64("POSTDEPLOY_MYSQL_DATABASE_B64"),
        mysql_user=required_env_b64("POSTDEPLOY_MYSQL_USER_B64"),
        mysql_password=required_env_b64("POSTDEPLOY_MYSQL_PASSWORD_B64"),
        image_urls=image_urls,
    )


def blob_name_for(index: int, sku: str | None) -> str:
    if sku:
        return f"product_{sku}.jpg"
    return f"product_extra_{index + 1:02d}.jpg"


def download_image(url: str) -> bytes:
    response = requests.get(url, timeout=45)
    response.raise_for_status()
    if not response.content:
        raise RuntimeError(f"Downloaded empty image from {url}")
    return response.content


def upload_images(settings: Settings) -> dict[str, str]:
    blob_service = BlobServiceClient(
        account_url=settings.storage_account_url,
        credential=settings.storage_account_key,
    )
    container = blob_service.get_container_client(settings.storage_container_name)
    try:
        container.create_container()
    except ResourceExistsError:
        pass

    sku_to_blob: dict[str, str] = {}
    uploaded = 0
    for index, url in enumerate(settings.image_urls):
        sku = PRODUCT_SKUS[index] if index < len(PRODUCT_SKUS) else None
        blob_name = blob_name_for(index, sku)
        image_bytes = download_image(url)
        container.upload_blob(
            name=blob_name,
            data=image_bytes,
            overwrite=True,
            content_settings=ContentSettings(content_type="image/jpeg"),
        )
        uploaded += 1
        print(f"uploaded\t{blob_name}\t{len(image_bytes)} bytes")
        if sku:
            sku_to_blob[sku] = blob_name

    print(f"uploaded_total\t{uploaded}")
    return sku_to_blob


def update_product_images(settings: Settings, sku_to_blob: dict[str, str]) -> int:
    if not sku_to_blob:
        return 0

    connection = pymysql.connect(
        host=settings.mysql_host,
        port=3306,
        user=settings.mysql_user,
        password=settings.mysql_password,
        database=settings.mysql_database,
        charset="utf8mb4",
        ssl={"ssl": {}},
        connect_timeout=15,
        autocommit=False,
    )
    try:
        updated = 0
        with connection.cursor() as cursor:
            for sku, blob_name in sku_to_blob.items():
                cursor.execute(
                    "UPDATE products SET image_blob = %s WHERE sku = %s",
                    (blob_name, sku),
                )
                updated += cursor.rowcount
        connection.commit()
        print(f"products_updated\t{updated}")
        return updated
    finally:
        connection.close()


def verify(settings: Settings) -> None:
    blob_service = BlobServiceClient(
        account_url=settings.storage_account_url,
        credential=settings.storage_account_key,
    )
    container = blob_service.get_container_client(settings.storage_container_name)
    expected_blobs = [blob_name_for(index, PRODUCT_SKUS[index] if index < len(PRODUCT_SKUS) else None) for index in range(len(settings.image_urls))]
    existing_blobs = {blob.name for blob in container.list_blobs(name_starts_with="product_")}
    missing_blobs = [blob_name for blob_name in expected_blobs if blob_name not in existing_blobs]
    if missing_blobs:
        raise RuntimeError(f"Missing uploaded blobs: {', '.join(missing_blobs)}")

    connection = pymysql.connect(
        host=settings.mysql_host,
        port=3306,
        user=settings.mysql_user,
        password=settings.mysql_password,
        database=settings.mysql_database,
        charset="utf8mb4",
        ssl={"ssl": {}},
        connect_timeout=15,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM products WHERE image_blob IS NOT NULL AND image_blob <> ''")
            products_with_images = cursor.fetchone()[0]
    finally:
        connection.close()

    print(f"verified_blobs\t{len(expected_blobs)}")
    print(f"products_with_images\t{products_with_images}")


def main() -> int:
    settings = load_settings()
    sku_to_blob = upload_images(settings)
    update_product_images(settings, sku_to_blob)
    verify(settings)
    print("Post-deploy image upload completed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)