#!/bin/bash

IS_FIRST=$(docker ps | grep -e blue -e green) # 현재 구동중인 App이 있는지 확인
IS_GREEN=$(docker ps | grep green) # 현재 실행중인 App이 blue인지 확인
DEFAULT_CONF=" /etc/nginx/nginx.conf"

if [ -z $IS_GREEN ];then # blue라면

  echo "### BLUE => GREEN ###"

  echo "1. get green image"
  docker-compose pull green # green으로 이미지를 내려받습니다.

  echo "2. green container up"
  docker-compose up -d green # green 컨테이너 실행

  if [ -n $IS_FIRST ];then # 해당 조건을 넣지 않으면 처음 구동 시 무한 루프 발생
      echo "first start"
  else
    while [ 1 = 1 ]; do
      echo "3. green health check..."
      sleep 3

      REQUEST=$(curl http://127.0.0.1:9000) # green으로 request
        if [ -n "$REQUEST" ]; then # 서비스 가능하면 health check 중지
          echo "health check success"
          break ;
        fi
    done;
  fi

  echo "4. reload nginx"
  sudo cp /etc/nginx/nginx.green.conf $DEFAULT_CONF
  sleep 5 # 복사 후 바로 nginx 재시작하면 에러 발생

  sudo nginx -s reload # nginx 재시작

  echo "5. blue container down"
  docker-compose stop blue
else
  echo "### GREEN => BLUE ###"

  echo "1. get blue image"
  docker-compose pull blue

  echo "2. blue container up"
  docker-compose up -d blue

  while [ 1 = 1 ]; do
    echo "3. blue health check..."
    sleep 3
    REQUEST=$(curl http://127.0.0.1:9001) # blue로 request

    if [ -n "$REQUEST" ]; then # 서비스 가능하면 health check 중지
      echo "health check success"
      break ;
    fi
  done;

  echo "4. reload nginx"
  sudo cp /etc/nginx/nginx.blue.conf $DEFAULT_CONF
  sleep 5 # 복사 후 바로 nginx 재시작하면 에러 발생

  sudo nginx -s reload # nginx 재시작

  echo "5. green container down"
  docker-compose stop green
fi