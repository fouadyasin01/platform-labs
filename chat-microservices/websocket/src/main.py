import asyncio
import os

import redis.asyncio as redis
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

clients: set[WebSocket] = set()
redis_task: asyncio.Task | None = None
redis_client: redis.Redis | None = None
pubsub: redis.client.PubSub | None = None


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    clients.add(websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        clients.discard(websocket)


async def redis_listener():
    global redis_client, pubsub

    redis_client = redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        decode_responses=True,
    )

    pubsub = redis_client.pubsub()
    await pubsub.subscribe("chat_messages")

    try:
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue

            disconnected = set()

            for websocket in clients.copy():
                try:
                    await websocket.send_text(message["data"])
                except Exception:
                    disconnected.add(websocket)

            clients.difference_update(disconnected)

    except asyncio.CancelledError:
        raise
    finally:
        if pubsub is not None:
            await pubsub.unsubscribe("chat_messages")
            await pubsub.close()

        if redis_client is not None:
            await redis_client.close()

        pubsub = None
        redis_client = None


@app.on_event("startup")
async def startup():
    global redis_task
    redis_task = asyncio.create_task(redis_listener())


@app.on_event("shutdown")
async def shutdown():
    global redis_task

    if redis_task is not None:
        redis_task.cancel()

        try:
            await redis_task
        except asyncio.CancelledError:
            pass

        redis_task = None

    disconnected = set()

    for websocket in clients.copy():
        try:
            await websocket.close(code=1001, reason="Server shutting down")
        except Exception:
            disconnected.add(websocket)

    clients.difference_update(disconnected)
    clients.clear()