USE assessment;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE
);

INSERT INTO users (name, email)
VALUES
    ('Altaf', 'altaf@example.com'),
    ('DevOps Assessment', 'bagwanmaltaf@gmail.com');
