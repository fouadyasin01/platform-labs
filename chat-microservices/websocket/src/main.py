import asyncio
import os

import redis.asyncio as redis
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

clients: set[WebSocket] = set()


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
    client = redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        decode_responses=True,
    )

    pubsub = client.pubsub()
    await pubsub.subscribe("chat_messages")

    async for message in pubsub.listen():
        if message["type"] != "message":
            continue

        disconnected = set()

        for websocket in clients:
            try:
                await websocket.send_text(message["data"])
            except Exception:
                disconnected.add(websocket)

        clients.difference_update(disconnected)


@app.on_event("startup")
async def startup():
    asyncio.create_task(redis_listener())


@app.on_event("shutdown")
async def shutdown():
    clients.clear()
