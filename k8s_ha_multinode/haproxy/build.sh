#!/bin/bash
docker build -t davarski/haproxy:latest .
docker push davarski/haproxy:latest

#docker build -t davarski/haproxy:`git rev-parse --short HEAD` .
