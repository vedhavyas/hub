FROM python:slim-buster
MAINTAINER Vedhavyas Singareddi

# Install cron
RUN apt-get update && apt-get install -y cron

WORKDIR /

COPY . .

RUN chmod +x /entrypoint.sh /media_cleaner.py

RUN pip3 install python-dateutil

ENTRYPOINT /entrypoint.sh
