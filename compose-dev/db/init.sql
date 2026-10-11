CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email)
VALUES
    ('Fouad Yasin', 'fouad@example.com'),
    ('Alice Smith', 'alice@example.com'),
    ('Bob Johnson', 'bob@example.com')
ON CONFLICT (email) DO NOTHING;
