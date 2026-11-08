import sys
from pathlib import Path
from unittest.mock import MagicMock

import pytest

APP_SRC = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(APP_SRC))

import app as api


@pytest.fixture
def client():
    api.app.config["TESTING"] = True
    with api.app.test_client() as test_client:
        yield test_client


def test_health_returns_healthy(client):
    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "healthy"}


def test_get_messages_returns_database_messages(client, monkeypatch):
    collection = MagicMock()
    collection.find.return_value.sort.return_value = [
        {"message": "Hello", "created_at": "2026-10-22T10:00:00+00:00"}
    ]
    monkeypatch.setattr(api, "messages_collection", collection)

    response = client.get("/api/messages")

    assert response.status_code == 200
    assert response.get_json() == [
        {"message": "Hello", "created_at": "2026-10-22T10:00:00+00:00"}
    ]
    collection.find.assert_called_once_with({}, {"_id": 0})


def test_create_message_rejects_empty_message(client):
    response = client.post("/api/messages", json={"message": "   "})

    assert response.status_code == 400
    assert response.get_json() == {"error": "message is required"}


def test_create_message_rejects_missing_message(client):
    response = client.post("/api/messages", json={})

    assert response.status_code == 400
    assert response.get_json() == {"error": "message is required"}


def test_create_message_saves_and_publishes(client, monkeypatch):
    collection = MagicMock()
    redis_client = MagicMock()

    monkeypatch.setattr(api, "messages_collection", collection)
    monkeypatch.setattr(api, "redis_client", redis_client)

    response = client.post(
        "/api/messages",
        json={"message": "  Hello from CI  "},
    )

    assert response.status_code == 201
    assert response.get_json() == {
        "message": "Hello from CI",
        "status": "published",
    }

    inserted_document = collection.insert_one.call_args.args[0]
    assert inserted_document["message"] == "Hello from CI"
    assert inserted_document["created_at"]

    redis_client.publish.assert_called_once_with("chat_messages", "Hello from CI")
