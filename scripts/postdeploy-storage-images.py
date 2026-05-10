import base64
import csv
import io
import os
import sys
from dataclasses import dataclass
from urllib.parse import urlparse

import pymysql
import requests
from azure.core.exceptions import ResourceExistsError
from azure.storage.blob import BlobServiceClient, ContentSettings


@dataclass(frozen=True)
class Settings:
    storage_account_url: str
    storage_account_key: str
    storage_container_name: str
    mysql_host: str
    mysql_database: str
    mysql_user: str
    mysql_password: str
    image_mappings: list[dict[str, str]]


def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def required_env_b64(name: str) -> str:
    return base64.b64decode(required_env(name)).decode("utf-8")


def load_settings() -> Settings:
    image_list_text = required_env_b64("POSTDEPLOY_IMAGE_URLS_B64")
    image_mappings = parse_image_mappings(image_list_text)
    if not image_mappings:
        raise RuntimeError("No image URLs were provided.")

    return Settings(
        storage_account_url=required_env_b64("POSTDEPLOY_STORAGE_ACCOUNT_URL_B64"),
        storage_account_key=required_env_b64("POSTDEPLOY_STORAGE_ACCOUNT_KEY_B64"),
        storage_container_name=required_env_b64("POSTDEPLOY_STORAGE_CONTAINER_B64"),
        mysql_host=required_env_b64("POSTDEPLOY_MYSQL_HOST_B64"),
        mysql_database=required_env_b64("POSTDEPLOY_MYSQL_DATABASE_B64"),
        mysql_user=required_env_b64("POSTDEPLOY_MYSQL_USER_B64"),
        mysql_password=required_env_b64("POSTDEPLOY_MYSQL_PASSWORD_B64"),
        image_mappings=image_mappings,
    )


def parse_image_mappings(image_list_text: str) -> list[dict[str, str]]:
    sample = image_list_text.lstrip()
    if sample.startswith("link,"):
        reader = csv.DictReader(io.StringIO(image_list_text))
        return [
            {"url": row["link"].strip(), "sku": row["id"].strip()}
            for row in reader
            if row.get("link", "").strip() and row.get("id", "").strip()
        ]

    mappings = []
    for index, line in enumerate(image_list_text.splitlines(), start=1):
        url = line.strip()
        if url:
            mappings.append({"url": url, "sku": f"UNMAPPED-{index:02d}"})
    return mappings


def extension_for(url: str) -> str:
    path = urlparse(url).path.lower()
    if path.endswith(".png"):
        return "png"
    if path.endswith(".webp"):
        return "webp"
    return "jpg"


def content_type_for(extension: str) -> str:
    if extension == "png":
        return "image/png"
    if extension == "webp":
        return "image/webp"
    return "image/jpeg"


def blob_name_for(sku: str, url: str) -> str:
    return f"product-images/{sku}.{extension_for(url)}"


def blob_url_for(settings: Settings, blob_name: str) -> str:
    return f"{settings.storage_account_url.rstrip('/')}/{settings.storage_container_name}/{blob_name}"


def download_image(url: str) -> bytes:
    response = requests.get(url, timeout=45)
    response.raise_for_status()
    if not response.content:
        raise RuntimeError(f"Downloaded empty image from {url}")
    return response.content


def clean_product_images(container) -> int:
    deleted = 0
    for prefix in ("product-images/", "product_"):
        for blob in container.list_blobs(name_starts_with=prefix):
            container.delete_blob(blob.name)
            deleted += 1
            print(f"deleted\t{blob.name}")
    print(f"deleted_total\t{deleted}")
    return deleted


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

    clean_product_images(container)

    sku_to_url: dict[str, str] = {}
    uploaded = 0
    for mapping in settings.image_mappings:
        url = mapping["url"]
        sku = mapping["sku"]
        blob_name = blob_name_for(sku, url)
        extension = extension_for(url)
        image_bytes = download_image(url)
        container.upload_blob(
            name=blob_name,
            data=image_bytes,
            overwrite=True,
            content_settings=ContentSettings(content_type=content_type_for(extension)),
        )
        uploaded += 1
        print(f"uploaded\t{blob_name}\t{len(image_bytes)} bytes")
        sku_to_url[sku] = blob_url_for(settings, blob_name)

    print(f"uploaded_total\t{uploaded}")
    return sku_to_url


def update_product_images(settings: Settings, sku_to_url: dict[str, str]) -> int:
    if not sku_to_url:
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
            for sku, image_url in sku_to_url.items():
                cursor.execute(
                    "UPDATE products SET image_blob = %s WHERE sku = %s",
                    (image_url, sku),
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
    expected_blobs = [blob_name_for(mapping["sku"], mapping["url"]) for mapping in settings.image_mappings]
    existing_blobs = {blob.name for blob in container.list_blobs(name_starts_with="product-images/")}
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
            skus = [mapping["sku"] for mapping in settings.image_mappings]
            sku_placeholders = ", ".join(["%s"] * len(skus))
            cursor.execute(
                f"SELECT COUNT(*) FROM products WHERE sku IN ({sku_placeholders}) AND image_blob LIKE %s",
                [*skus, f"{settings.storage_account_url.rstrip('/')}%"],
            )
            products_with_images = cursor.fetchone()[0]
    finally:
        connection.close()

    print(f"verified_blobs\t{len(expected_blobs)}")
    print(f"products_with_storage_urls\t{products_with_images}")


def main() -> int:
    settings = load_settings()
    sku_to_url = upload_images(settings)
    update_product_images(settings, sku_to_url)
    verify(settings)
    print("Post-deploy image upload completed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)