FROM java:8
ARG workdir=/data/spring-boot/
ENV app=spring-boot-docker-1.0.jar
ENV logPath="-DLOG_PATH=/data/spring-boot/log"

COPY spring-boot-docker/target/${app} ${workdir}
WORKDIR ${workdir}
EXPOSE 8080
RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo "Asia/Shanghai" > /etc/timezone
ENTRYPOINT ["sh","-c","java $logPath -Djava.security.egd=file:/dev/./urandom -jar $app"]
