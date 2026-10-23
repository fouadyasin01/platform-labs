export function initializeChatApp({
    document,
    fetchImpl = fetch,
    WebSocketImpl = WebSocket,
    locationObj = window.location,
    alertImpl = alert,
    consoleObj = console,
}) {
    const status = document.getElementById("status");
    const messages = document.getElementById("messages");
    const form = document.getElementById("message-form");
    const input = document.getElementById("message-input");

    function addMessage(text) {
        const message = document.createElement("div");
        message.className = "message";
        message.textContent = text;
        messages.appendChild(message);
    }

    async function loadMessages() {
        try {
            const response = await fetchImpl("/api/messages");

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            data.forEach((item) => addMessage(item.message));
        } catch (error) {
            consoleObj.error("Failed to load messages:", error);
        }
    }

    const protocol = locationObj.protocol === "https:" ? "wss" : "ws";
    const socket = new WebSocketImpl(
        `${protocol}://${locationObj.host}/ws`
    );

    socket.onopen = () => {
        status.textContent = "🟢 Connected";
    };

    socket.onclose = () => {
        status.textContent = "🔴 Disconnected";
    };

    socket.onerror = () => {
        status.textContent = "🔴 Connection error";
    };

    socket.onmessage = (event) => {
        addMessage(event.data);
    };

    form.addEventListener("submit", async (event) => {
        event.preventDefault();

        const message = input.value.trim();

        if (!message) {
            return;
        }

        try {
            const response = await fetchImpl("/api/messages", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({ message }),
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            input.value = "";
            input.focus();
        } catch (error) {
            consoleObj.error("Failed to send message:", error);
            alertImpl("Failed to send message");
        }
    });

    return { addMessage, loadMessages, socket };
}
