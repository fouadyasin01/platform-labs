import os
from datetime import datetime, timezone
from flask import Flask, jsonify, request
from flask_cors import CORS
from pymongo import MongoClient
import redis

app = Flask(__name__)
CORS(app)


MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

mongo_client = MongoClient(MONGO_URI)
db = mongo_client["chat"]
messages_collection = db["messages"]

redis_client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,
)


@app.get("/api/health")
def health():
    return jsonify({"status": "healthy"})


@app.get("/api/messages")
def get_messages():
    messages = list(
        messages_collection.find(
            {},
            {"_id": 0}
        ).sort("created_at", 1)
    )

    return jsonify(messages)


@app.post("/api/messages")
def create_message():
    data = request.get_json(silent=True) or {}
    message = data.get("message", "").strip()

    if not message:
        return jsonify({"error": "message is required"}), 400

    document = {
        "message": message,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    messages_collection.insert_one(document)

    redis_client.publish("chat_messages", message)

    return jsonify({
        "message": message,
        "status": "published"
    }), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3001)
