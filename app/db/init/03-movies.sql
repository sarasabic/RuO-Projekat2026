\connect quiz
SET client_min_messages = warning;

INSERT INTO quiz.movies (title, emojis, year) VALUES
  ('Titanic',                  '🚢🧊💔',     1997),
  ('The Lion King',            '🦁👑🌅',     1994),
  ('Jaws',                     '🦈🌊😱',     1975),
  ('Finding Nemo',             '🔍🐠🌊',     2003),
  ('Frozen',                   '❄️👸⛄',     2013),
  ('Jurassic Park',            '🦖🏝️🚙',     1993),
  ('Toy Story',                '🧸🤠🚀',     1995),
  ('Star Wars',                '⭐⚔️🌌',     1977),
  ('The Matrix',               '💊🕶️💻',     1999),
  ('Up',                       '🎈🏠👴',     2009),
  ('Cars',                     '🚗⚡🏁',     2006),
  ('Ratatouille',              '🐀👨‍🍳🍲',   2007),
  ('Home Alone',               '🏠👦🎄',     1990),
  ('Back to the Future',       '🔙🚗⏰',     1985),
  ('Kung Fu Panda',            '🥋🐼🥟',     2008),
  ('Ice Age',                  '🧊🐿️🦣',     2002),
  ('E.T.',                     '👽🚲🌕',     1982),
  ('Ghostbusters',             '👻🚫📞',     1984),
  ('Pirates of the Caribbean', '🏴‍☠️🌴⚓',   2003),
  ('Shrek',                    '🟢👹🏰',     2001),
  ('Inception',                '💤🌀🏙️',     2010),
  ('Madagascar',               '🦓🦁🦒🦛',   2005)
ON CONFLICT (title) DO NOTHING;