git pull
docker build -t band-huddle .
docker-compose up --scale band-huddle=2 -d --no-deps band-huddle
docker image prune
