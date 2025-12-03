git pull
docker build -t bandmate .
docker-compose up --scale bandmate=2 -d --no-deps bandmate
docker image prune
