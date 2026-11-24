-- LR5, задание 3, шаг 3: учебная таблица
CREATE TABLE notes (
    id         SERIAL PRIMARY KEY,
    body       VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO notes (body) VALUES ('first'), ('second'), ('third');
SELECT * FROM notes;
