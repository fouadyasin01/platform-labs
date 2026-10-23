import { beforeEach, describe, expect, it, vi } from "vitest";
import { initializeChatApp } from "../web/app.js";

function createResponse(data, ok = true, status = 200) {
    return {
        ok,
        status,
        json: vi.fn().mockResolvedValue(data),
    };
}

function setup({
    fetchImpl = vi.fn().mockResolvedValue(createResponse([])),
    protocol = "http:",
} = {}) {
    document.body.innerHTML = `
        <div id="status">Connecting...</div>
        <div id="messages"></div>
        <form id="message-form">
            <input id="message-input" />
            <button type="submit">Send</button>
        </form>
    `;

    class MockWebSocket {
        constructor(url) {
            this.url = url;
            this.onopen = null;
            this.onclose = null;
            this.onerror = null;
            this.onmessage = null;
        }
    }

    const alertImpl = vi.fn();
    const consoleObj = { error: vi.fn() };

    const app = initializeChatApp({
        document,
        fetchImpl,
        WebSocketImpl: MockWebSocket,
        locationObj: { protocol, host: "localhost:8080" },
        alertImpl,
        consoleObj,
    });

    return {
        ...app,
        fetchImpl,
        alertImpl,
        consoleObj,
        status: document.getElementById("status"),
        messages: document.getElementById("messages"),
        form: document.getElementById("message-form"),
        input: document.getElementById("message-input"),
    };
}

describe("MicroChat frontend", () => {
    beforeEach(() => {
        vi.restoreAllMocks();
    });

    it("renders messages as text, not HTML", () => {
        const app = setup();

        app.addMessage("<img src=x onerror=alert(1)>");

        expect(app.messages.textContent).toBe(
            "<img src=x onerror=alert(1)>"
        );
        expect(app.messages.querySelector("img")).toBeNull();
    });

    it("loads and displays messages from the API", async () => {
        const fetchImpl = vi.fn().mockResolvedValue(
            createResponse([
                { message: "Hello" },
                { message: "Welcome" },
            ])
        );
        const app = setup({ fetchImpl });

        await app.loadMessages();

        expect(fetchImpl).toHaveBeenCalledWith("/api/messages");
        expect(app.messages.querySelectorAll(".message")).toHaveLength(2);
        expect(app.messages.textContent).toContain("Hello");
        expect(app.messages.textContent).toContain("Welcome");
    });

    it("logs an API error when loading messages fails", async () => {
        const fetchImpl = vi.fn().mockResolvedValue(
            createResponse({}, false, 500)
        );
        const app = setup({ fetchImpl });

        await app.loadMessages();

        expect(app.consoleObj.error).toHaveBeenCalledWith(
            "Failed to load messages:",
            expect.any(Error)
        );
    });

    it("logs network errors when loading messages", async () => {
        const app = setup({
            fetchImpl: vi.fn().mockRejectedValue(new Error("Network error")),
        });

        await app.loadMessages();

        expect(app.consoleObj.error).toHaveBeenCalled();
    });

    it("uses secure WebSocket on HTTPS", () => {
        const app = setup({ protocol: "https:" });

        expect(app.socket.url).toBe("wss://localhost:8080/ws");
    });

    it("updates status for WebSocket connection events", () => {
        const app = setup();

        app.socket.onopen();
        expect(app.status.textContent).toBe("🟢 Connected");

        app.socket.onclose();
        expect(app.status.textContent).toBe("🔴 Disconnected");

        app.socket.onerror();
        expect(app.status.textContent).toBe("🔴 Connection error");
    });

    it("renders incoming WebSocket messages", () => {
        const app = setup();

        app.socket.onmessage({ data: "Realtime message" });

        expect(app.messages.textContent).toContain("Realtime message");
    });


    it("sends a trimmed message and clears the input", async () => {
        const fetchImpl = vi.fn().mockResolvedValue(createResponse({}));
        const app = setup({ fetchImpl });

        app.input.value = "  Hello team  ";

        app.form.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true })
        );

        await vi.waitFor(() => {
            expect(fetchImpl).toHaveBeenCalledWith("/api/messages", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ message: "Hello team" }),
            });

            expect(app.input.value).toBe("");
        });
    });


    it("does not send an empty message", async () => {
        const fetchImpl = vi.fn();
        const app = setup({ fetchImpl });

        app.input.value = "   ";
        app.form.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true })
        );

        await Promise.resolve();

        expect(fetchImpl).not.toHaveBeenCalled();
    });

    it("preserves the input and alerts when sending fails", async () => {
        const fetchImpl = vi.fn().mockResolvedValue(
            createResponse({}, false, 500)
        );
        const app = setup({ fetchImpl });

        app.input.value = "Please keep this";
        app.form.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true })
        );

        await vi.waitFor(() => {
            expect(app.alertImpl).toHaveBeenCalledWith(
                "Failed to send message"
            );
        });

        expect(app.input.value).toBe("Please keep this");
        expect(app.consoleObj.error).toHaveBeenCalled();
    });

    it("alerts when sending fails due to a network error", async () => {
        const app = setup({
            fetchImpl: vi.fn().mockRejectedValue(new Error("Offline")),
        });

        app.input.value = "Retry me";
        app.form.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true })
        );

        await vi.waitFor(() => {
            expect(app.alertImpl).toHaveBeenCalledWith(
                "Failed to send message"
            );
        });

        expect(app.input.value).toBe("Retry me");
    });
});
