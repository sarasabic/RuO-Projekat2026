-- Objekte kreira i posjeduje quiz_owner
-- Uloga backenda (quiz_app) ne može izbrisati ili promijeniti.

\connect quiz
SET client_min_messages = warning;

SET ROLE quiz_owner;

CREATE SCHEMA quiz;

CREATE TABLE quiz.movies (
  id      int  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title   text NOT NULL UNIQUE,
  emojis  text NOT NULL,
  year    int  NOT NULL CHECK (year BETWEEN 1900 AND 2100)
);

CREATE TABLE quiz.scores (
  id        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  player    text        NOT NULL CHECK (char_length(player) BETWEEN 1 AND 20),
  points    int         NOT NULL CHECK (points >= 0),
  played_at timestamptz NOT NULL DEFAULT now()
);

RESET ROLE;

-- Privileges:
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA quiz TO quiz_app;
GRANT SELECT ON quiz.movies TO quiz_app;
GRANT SELECT, INSERT ON quiz.scores TO quiz_app;