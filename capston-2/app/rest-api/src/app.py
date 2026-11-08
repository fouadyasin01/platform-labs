import os
from datetime import UTC, datetime

import redis
from flask import Flask, jsonify, request
from flask_cors import CORS
from pymongo import MongoClient

app = Flask(__name__)
CORS(app)

MONGO_URI = (
    f"mongodb://{os.getenv('MONGO_USERNAME')}:{os.getenv('MONGO_PASSWORD')}"
    f"@{os.getenv('MONGO_HOST', 'localhost')}:{os.getenv('MONGO_PORT', '27017')}/chat?authSource=admin"
)
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD")

mongo_client = MongoClient(MONGO_URI)
db = mongo_client["chat"]
messages_collection = db["messages"]

redis_client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD,
    decode_responses=True,
)


@app.get("/api/health")
def health():
    return jsonify({"status": "healthy"})


@app.get("/api/messages")
def get_messages():
    messages = list(messages_collection.find({}, {"_id": 0}).sort("created_at", 1))

    return jsonify(messages)


@app.post("/api/messages")
def create_message():
    data = request.get_json(silent=True) or {}
    message = data.get("message", "").strip()

    if not message:
        return jsonify({"error": "message is required"}), 400

    document = {
        "message": message,
        "created_at": datetime.now(UTC).isoformat(),
    }
    messages_collection.insert_one(document)

    redis_client.publish("chat_messages", message)

    return jsonify({"message": message, "status": "published"}), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3001)
