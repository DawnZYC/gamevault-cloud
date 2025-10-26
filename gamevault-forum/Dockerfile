#FROM openjdk:17-jre-slim
#WORKDIR /app
#RUN apk add --no-cache curl
#RUN addgroup -S appgroup && adduser -S appuser -G appgroup
#COPY target/*.jar app.jar
#RUN chown -R appuser:appgroup /app
#USER appuser
#EXPOSE 8083
#HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
#    CMD curl -f http://localhost:8083/actuator/health || exit 1
#ENTRYPOINT ["java", "-jar", "app.jar"]

FROM openjdk:17-jre-slim

# 设置时区为新加坡时间
ENV TZ=Asia/Singapore

WORKDIR /app

RUN apk add --no-cache tzdata curl

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --chown=appuser:appgroup target/*.jar app.jar

USER appuser

EXPOSE 8083

# JVM 参数优化
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Djava.security.egd=file:/dev/./urandom"

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8083/actuator/health || exit 1

# 启动应用
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]