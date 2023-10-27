# Github Action을 이용한 배포
## 환경
- spring boot
- Cloud (dev -> AWS EC2, prod -> NCP Server)
- Github Action
- Nginx (무중단 배포에 사용)

## AWS EC2 생성
- Amazon Linux
- 스토리지 Size: 30GB
- 인바운드 규칙: 포트 80, 9000 추가

## EC Instance Docker 설치
```markdown
// 도커 설치
sudo yum install docker -y

// 도커 실행
sudo service docker start

// Docker 관련 권한 추가
sudo chmod 666 /var/run/docker.sock

// Docker 설치 확인
docker ps

// 도커 컴포즈 설치
sudo curl \
-L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" \
-o /usr/local/bin/docker-compose

// 권한 추가
sudo chmod +x /usr/local/bin/docker-compose

// 버전 확인
docker-compose --version

// 도커 컴포즈 실행 에러가 나면 하기 명령어로 libxcrypt-compat 설치
sudo dnf install libxcrypt-compat
```


## dockerfile 작성
- 'docker/' 에 작성
- dev 배포: Dockerfile-dev
- prod 배포: Dockerfile-prod


## workflows 작성
- '.github/workflows/' 에 작성
- dev 배포: github-action-test-dev.yml
- prod 배포: github-action-test-prod.yml


## Secrets 세팅
- Github Repository > Settings > Secrets and variables > Actions > New repository secret 작성
- workflow 파일에서 ${{ secrets.(value) }} 형태로 사용할 수 있다.


# 무중단 배포
## Nginx 세팅
- ‘nginx/’ 참고
- Nginx의 port 설정을 바꿔 간단하게 무중단 배포를 하는 방식으로 진행

### Nginx 설치 및 실행

```bash
yum install nginx // nginx 설치
sudo service nginx start // nginx 실행
```

### Nginx 세팅

- ‘/etc/nginx’ 경로에 nginx.blue.conf, nginx.green.conf 작성
- blue는 9000, green은 9001 포트로 설정
- nginx.blue.conf
    
    ```bash
    worker_processes  1;
    
    events {
        worker_connections  1024;
    }
    
    http {
        include       mime.types;
        default_type  application/octet-stream;
    
        sendfile        on;
    
        keepalive_timeout  65;
        types_hash_max_size 4096;
    
        server {
            listen       80;
            server_name  localhost;
    
            error_page   500 502 503 504  /50x.html;
            location = /50x.html {
                root   html;
            }
    
            location / {
                    proxy_pass http://127.0.0.1:9000;
                    proxy_set_header Host $host;
            }
        }
    }
    ```
    
- nginx.green.conf
    - proxy_pass의 포트만 변경
    
    ```bash
       			location / {
                    proxy_pass http://127.0.0.1:9001;
                    proxy_set_header Host $host;
            }
    ```
    

## Docker Compose 작성
- ‘docker/docker-compose.yml’ 참고
- docker-compose.yml
    
    ```yaml
    version: '3'
    
    services:
      blue:
        image: binsin/github-action-test-dev
        container_name: blue # 컨테이너명을 blue로 세팅
        environment:
          - LANG=ko_KR.UTF-8
          - UWSGI_PORT=9000
        ports:
          - '9000:9000' # docker 내부의 9000포트를 외부로는 9000으로 오픈
      green:
        image: binsin/github-action-test-dev
        container_name: green # 컨테이너명을 green으로 세팅
        environment:
          - LANG=ko_KR.UTF-8
          - UWSGI_PORT=9000
        ports:
          - '9001:9000' # docker 내부의 9000포트를 외부로는 9001로 오픈
    ```
    

## 실행 스크립트 작성
- ‘script/’ 참고
- 무중단 배포를 위한 스크립트 작성을 해야 한다.
- 서버에 로그인하는 계정의 홈 디렉토리에 deploy.sh 작성
- 작성 후 하기 명령어로 실행 권한 줘야함
    
    ```bash
    sudo chmod 777 deploy.sh
    ```
    
- deploy.sh
    - docker ps 명령어로  blue/green 구동 여부를 파악하여 스위칭하는 스크립트
    
    ```bash
    #!/bin/bash
    
    IS_FIRST=$(docker ps | grep -e blue -e green) # 현재 구동중인 App이 있는지 확인
    IS_GREEN=$(docker ps | grep green) # 현재 실행중인 App이 blue인지 확인
    DEFAULT_CONF=" /etc/nginx/nginx.conf"
    
    if [ -n $IS_GREEN ];then # blue라면
    
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
    ```
    

## Github Action Workflow 변경
- ‘.github/workflows/’ 참고
- Deploy 하는 부분 변경
    - 직접 docker를 실행시키지 않고 deploy.sh 스크립트를 실행하여 nginx에서 바라보는 포트를 변경
    - before
        
        ```yaml
        script: |
                    docker login -u ${{ secrets.DOCKER_USERNAME }} -p ${{ secrets.DOCKER_PASSWORD }} ${{ secrets.DOCKER_REPOSITORY }}/dev
                    docker rm -f $(docker ps --filter label="project=github-action-dev" -q)
                    docker pull ${{ secrets.DOCKER_REPOSITORY }}/dev
                    docker run -d -v /app_log/github-action-dev:/app_log/github-action-dev -p 8080:8080 ${{ secrets.DOCKER_REPOSITORY }}/dev
                    docker image prune -f
        ```
        
    - after
        
        ```yaml
        script: |
                    docker login -u ${{ secrets.DOCKER_USERNAME }} -p ${{ secrets.DOCKER_PASSWORD }}
                    docker pull ${{ secrets.DOCKER_REPOSITORY_DEV }}/${{ secrets.DOCKER_REPOSITORY_DEV }}
                    ./deploy.sh
                    docker image prune -f
        ```
        
- 끝!
