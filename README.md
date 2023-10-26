# Github Action을 이용한 배포

## 환경
- spring boot
- Cloud (dev -> AWS EC2, prod -> NCP Server)
- Github Action

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
