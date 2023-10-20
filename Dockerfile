# profile environment
FROM openjdk:17-alpine

VOLUME ["/app_log/github-action-test"]
LABEL project="github-action-test"

ADD api/build/libs/clingy-api.jar clingy-api.jar
EXPOSE 8080
RUN sh -c 'touch /github-action-test.jar'
ENV JAVA_OPTS="-Dspring.profiles.active=dev"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /github-action-test.jar"]