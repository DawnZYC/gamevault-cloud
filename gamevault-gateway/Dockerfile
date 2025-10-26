# ==========================================
# Dockerfile for Gateway Service
# ==========================================

FROM eclipse-temurin:17-jre-jammy

# 设置时区为新加坡时间
ENV TZ=Asia/Singapore
RUN apt-get update && apt-get install -y tzdata curl && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 创建应用用户和组
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

# 复制配置文件
RUN mkdir -p /app/config
COPY --chown=appuser:appgroup src/main/resources/application-prod.yml /app/config/

# 复制 JAR 文件
COPY --chown=appuser:appgroup target/*.jar app.jar

# 切换到应用用户
USER appuser

# 暴露端口
EXPOSE 8080

# JVM 参数优化
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Djava.security.egd=file:/dev/./urandom"

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# 启动应用
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
