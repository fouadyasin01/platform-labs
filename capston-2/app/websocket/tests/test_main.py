import sys
from pathlib import Path

from fastapi.testclient import TestClient

APP_SRC = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(APP_SRC))

from main import app


def test_health_returns_healthy():
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_websocket_accepts_connection_and_disconnects():
    with TestClient(app) as client, client.websocket_connect("/ws"):
        pass


def test_redis_listener_retries_after_connection_failure(monkeypatch):
    import asyncio

    import main

    class BrokenRedis:
        def __init__(self, **kwargs):
            pass

        async def ping(self):
            raise ConnectionError("Redis unavailable")

    async def stop_after_retry(_delay):
        raise asyncio.CancelledError

    monkeypatch.setattr(main.redis, "Redis", BrokenRedis)
    monkeypatch.setattr(main.asyncio, "sleep", stop_after_retry)

    try:
        asyncio.run(main.redis_listener())
    except asyncio.CancelledError:
        pass


def test_redis_listener_cleans_up_after_subscription(monkeypatch):
    import asyncio

    import main

    class FakePubSub:
        async def subscribe(self, channel):
            assert channel == "chat_messages"

        async def listen(self):
            if False:
                yield {}
            raise RuntimeError("listener stopped")

        async def aclose(self):
            self.closed = True

    class FakeRedis:
        def __init__(self, **kwargs):
            self.pubsub_instance = FakePubSub()

        async def ping(self):
            return True

        def pubsub(self):
            return self.pubsub_instance

        async def aclose(self):
            self.closed = True

    redis_instances = []

    def create_redis(**kwargs):
        instance = FakeRedis(**kwargs)
        redis_instances.append(instance)
        return instance

    async def stop_after_retry(_delay):
        raise asyncio.CancelledError

    monkeypatch.setattr(main.redis, "Redis", create_redis)
    monkeypatch.setattr(main.asyncio, "sleep", stop_after_retry)

    try:
        asyncio.run(main.redis_listener())
    except asyncio.CancelledError:
        pass

    assert redis_instances
    assert redis_instances[0].pubsub_instance.closed
    assert redis_instances[0].closed
