CREATE TABLE IF NOT EXISTS patients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL
);

INSERT INTO patients (name, status)
VALUES
    ('Fouad Yasin', 'active'),
    ('Bob Smith', 'active'),
    ('Charlie Brown', 'inactive')
ON CONFLICT DO NOTHING;
