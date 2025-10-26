#FROM eclipse-temurin:17-jre-alpine
#WORKDIR /app
#RUN apk add --no-cache curl
#RUN addgroup -S appgroup && adduser -S appuser -G appgroup
#COPY gamevault-shopping/target/*.jar app.jar
#RUN chown -R appuser:appgroup /app
#USER appuser
#EXPOSE 8082
#HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
#    CMD curl -f http://localhost:8082/actuator/health || exit 1
#ENTRYPOINT ["java", "-jar", "app.jar"]

# ==========================================
# Dockerfile for Shopping Service
# ==========================================

FROM eclipse-temurin:17-jre-alpine

# 设置时区为新加坡时间
ENV TZ=Asia/Singapore
RUN apk add --no-cache tzdata curl && \
    cp /usr/share/zoneinfo/Asia/Singapore /etc/localtime && \
    echo "Asia/Singapore" > /etc/timezone && \
    apk del tzdata

# 设置工作目录
WORKDIR /app

# 创建应用用户和组
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 复制 JAR 文件 (CI 已经构建好)
COPY target/*.jar app.jar

# 修改文件所有权
RUN chown -R appuser:appgroup /app

# 切换到应用用户
USER appuser

# 暴露端口
EXPOSE 8082

# JVM 参数优化
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Djava.security.egd=file:/dev/./urandom"

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8082/actuator/health || exit 1

# 启动应用
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]