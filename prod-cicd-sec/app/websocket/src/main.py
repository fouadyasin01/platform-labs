
import asyncio
import os
import socket
from contextlib import suppress

import redis.asyncio as redis
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD")
REDIS_CHANNEL = "chat_messages"
RETRY_DELAY = 5

POD_NAME = os.getenv("HOSTNAME", socket.gethostname())

clients: set[WebSocket] = set()
redis_task: asyncio.Task | None = None


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    clients.add(websocket)
    print(f"[{POD_NAME}] WebSocket client connected", flush=True)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        clients.discard(websocket)
        print(f"[{POD_NAME}] WebSocket client disconnected", flush=True)


async def redis_listener():
    """Subscribe to Redis and retry automatically after failures."""

    while True:
        redis_client = None
        pubsub = None

        try:
            redis_client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                password=REDIS_PASSWORD,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=30,
                health_check_interval=15,
            )

            await redis_client.ping()
            pubsub = redis_client.pubsub()
            await pubsub.subscribe(REDIS_CHANNEL)

            print(
                f"[{POD_NAME}] Subscribed to Redis channel "
                f"{REDIS_CHANNEL} at {REDIS_HOST}:{REDIS_PORT}",
                flush=True,
            )

            async for message in pubsub.listen():
                if message["type"] != "message":
                    continue

                print(
                    f"[{POD_NAME}] Received Redis message: "
                    f"{message['data']!r}; clients={len(clients)}",
                    flush=True,
                )

                disconnected = set()

                for websocket in clients.copy():
                    try:
                        await websocket.send_text(message["data"])
                    except Exception as exc:
                        print(
                            f"[{POD_NAME}] WebSocket send failed: {exc}",
                            flush=True,
                        )
                        disconnected.add(websocket)

                clients.difference_update(disconnected)

            print(
                f"[{POD_NAME}] Redis listener ended; reconnecting",
                flush=True,
            )

        except asyncio.CancelledError:
            raise

        except Exception as exc:
            print(
                f"[{POD_NAME}] Redis listener error: "
                f"{type(exc).__name__}: {exc}",
                flush=True,
            )

        finally:
            if pubsub is not None:
                try:
                    await pubsub.aclose()
                except Exception as exc:
                    print(
                        f"[{POD_NAME}] Pub/Sub cleanup error: {exc}",
                        flush=True,
                    )

            if redis_client is not None:
                try:
                    await redis_client.aclose()
                except Exception as exc:
                    print(
                        f"[{POD_NAME}] Redis cleanup error: {exc}",
                        flush=True,
                    )

        await asyncio.sleep(RETRY_DELAY)


@app.on_event("startup")
async def startup():
    global redis_task

    redis_task = asyncio.create_task(redis_listener())
    print(f"[{POD_NAME}] WebSocket service started", flush=True)


@app.on_event("shutdown")
async def shutdown():
    global redis_task

    if redis_task is not None:
        redis_task.cancel()

        with suppress(asyncio.CancelledError):
            await redis_task

        redis_task = None

    for websocket in clients.copy():
        with suppress(Exception):
            await websocket.close(
                code=1001,
                reason="Server shutting down",
            )

    clients.clear()
