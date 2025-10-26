#!/bin/bash

# GameVault 配置更新脚本
# 用于更新生产环境配置文件

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 更新生产环境配置
update_prod_configs() {
    log_info "更新生产环境配置..."
    
    # 更新认证服务配置
    update_auth_config
    update_gateway_config
    update_social_config
    update_shopping_config
    update_forum_config
    update_developer_config
    
    log_success "配置更新完成"
}

# 更新认证服务配置
update_auth_config() {
    log_info "更新认证服务配置..."
    
    cat > gamevault-auth/src/main/resources/application-prod.yml << 'EOF'
server:
  port: 8081
  tomcat:
    threads:
      max: 200
      min-spare: 10
    connection-timeout: 20000
    accept-count: 100

spring:
  application:
    name: gamevault-auth

  datasource:
    url: jdbc:postgresql://postgres:5432/gamevault_auth
    username: gamevault_user
    password: gamevault_pass
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
      connection-test-query: SELECT 1

  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: update
    show-sql: false
    properties:
      hibernate:
        format_sql: false
        jdbc:
          batch_size: 20
        order_inserts: true
        order_updates: true

  servlet:
    multipart:
      enabled: true
      max-file-size: 10MB
      max-request-size: 50MB
      file-size-threshold: 2MB
      location: /uploads

  cloud:
    nacos:
      discovery:
        server-addr: nacos:8848
        namespace: prod
        group: GAMEVAULT_GROUP
        ip: ${POD_IP:auth}
        register-enabled: true
        heart-beat-interval: 5000
        heart-beat-timeout: 15000
      config:
        server-addr: nacos:8848
        namespace: prod
        group: GAMEVAULT_GROUP
        file-extension: yml
        enabled: false
        import-check:
          enabled: false

rsa:
  private-key: classpath:certs/rsa-private.pem
  public-key: classpath:certs/rsa-public.pem

app:
  jwt:
    expiration-minutes: 120

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
      base-path: /actuator
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
  health:
    livenessState:
      enabled: true
    readinessState:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true

logging:
  level:
    root: INFO
    com.sg.nusiss.auth: INFO
    org.springframework.security: INFO
    org.springframework.web: INFO
    org.hibernate.SQL: WARN
    org.hibernate.type.descriptor.sql.BasicBinder: WARN
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
    file: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
  file:
    name: /app/logs/auth-service.log
    max-size: 100MB
    max-history: 30
    total-size-cap: 1GB
EOF
}

# 更新网关配置
update_gateway_config() {
    log_info "更新网关配置..."
    
    cat > gamevault-gateway/src/main/resources/application-prod.yml << 'EOF'
server:
  port: 8080
  netty:
    connection-timeout: 30s
    idle-timeout: 60s

spring:
  application:
    name: gamevault-gateway

  cloud:
    nacos:
      discovery:
        server-addr: nacos:8848
        namespace: prod
        group: GAMEVAULT_GROUP
        ip: ${POD_IP:gateway}
        register-enabled: true
        heart-beat-interval: 5000
        heart-beat-timeout: 15000
      config:
        enabled: false

    import-check:
      enabled: false

    gateway:
      routes:
        - id: auth-service
          uri: lb://gamevault-auth
          predicates:
            - Path=/api/auth/**, /.well-known/jwks.json, /api/settings/**
          filters:
            - StripPrefix=0

        - id: shopping-service
          uri: lb://gamevault-shopping
          predicates:
            - Path=/api/games/**,/api/library/**,/api/cart/**,/api/orders/**,/api/admin/games/**,/api/user/activation-codes/**
          filters:
            - StripPrefix=0

        - id: developer-service
          uri: lb://gamevault-developer
          predicates:
            - Path=/api/developer/**
          filters:
            - StripPrefix=0

        - id: social-websocket
          uri: lb:ws://gamevault-social
          predicates:
            - Path=/ws/info/**,/ws/**
          filters:
            - StripPrefix=0

        - id: social-service
          uri: lb://gamevault-social
          predicates:
            - Path=/api/conversation/**,/api/friend/**,/api/message/**,/api/file/**
          filters:
            - StripPrefix=0

        - id: forum-service
          uri: lb://gamevault-forum
          predicates:
            - Path=/api/forum/**
          filters:
            - StripPrefix=0

        - id: profile-service
          uri: lb://gamevault-profile
          predicates:
            - Path=/api/settings/**,/api/profile/**
          filters:
            - StripPrefix=0

      httpclient:
        connect-timeout: 10000
        response-timeout: 30s
        pool:
          type: elastic
          max-connections: 100
          max-idle-time: 30s

management:
  endpoints:
    web:
      exposure:
        include: health,info,gateway,routes,metrics,prometheus
      base-path: /actuator
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: false
    gateway:
      enabled: true
  health:
    livenessState:
      enabled: false
    readinessState:
      enabled: false
  metrics:
    export:
      prometheus:
        enabled: true

logging:
  level:
    root: INFO
    org.springframework.cloud.gateway: INFO
    org.springframework.web: INFO
    reactor.netty: INFO
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
    file: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
  file:
    name: /app/logs/gateway-service.log
    max-size: 100MB
    max-history: 30
    total-size-cap: 1GB
EOF
}

# 更新社交服务配置
update_social_config() {
    log_info "更新社交服务配置..."
    
    cat > gamevault-social/src/main/resources/application-prod.yml << 'EOF'
server:
  port: 8089
  tomcat:
    max-swallow-size: 100MB
    max-http-form-post-size: 100MB

spring:
  application:
    name: gamevault-social

  cloud:
    compatibility-verifier:
      enabled: false
    nacos:
      discovery:
        server-addr: nacos:8848
        namespace: prod
        group: GAMEVAULT_GROUP
        ip: ${POD_IP:social}
        register-enabled: true
        heart-beat-interval: 5000
        heart-beat-timeout: 15000
      config:
        enabled: false
        import-check:
          enabled: false

  security:
    oauth2:
      resourceserver:
        jwt:
          public-key-location: classpath:certs/rsa-public.pem

  datasource:
    url: jdbc:postgresql://postgres:5432/gamevault_social
    username: gamevault_user
    password: gamevault_pass

  jpa:
    hibernate:
      ddl-auto: update
      naming:
        physical-strategy: org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
    show-sql: false

  servlet:
    multipart:
      max-file-size: 100MB
      max-request-size: 100MB
      enabled: true

  data:
    redis:
      host: redis
      database: 1
      port: 6379
      password: redis_pass
      timeout: 3000ms
      lettuce:
        pool:
          max-active: 8
          max-idle: 8
          min-idle: 0
          max-wait: -1ms

minio:
  endpoint: http://minio:9000
  public-endpoint: http://minio:9000
  access-key: minioadmin
  secret-key: minioadmin123
  bucket-name: gamevault-chat
  image-bucket: gamevault-images
  video-bucket: gamevault-videos
  file-bucket: gamevault-files
  audio-bucket: gamevault-audios

file:
  upload:
    temp-path: ${java.io.tmpdir}/gamevault-uploads
    image:
      max-size: 10485760
      allowed-types: jpg,jpeg,png,gif,webp,bmp,svg
      generate-thumbnail: true
      thumbnail-width: 200
      thumbnail-height: 200
    video:
      max-size: 524288000
      allowed-types: mp4,avi,mov,wmv,flv,mkv,webm,m4v
      generate-cover: true
    document:
      max-size: 20971520
      allowed-types: pdf,doc,docx,xls,xlsx,ppt,pptx,txt,zip,rar,7z
    audio:
      max-size: 52428800
      allowed-types: mp3,wav,aac,flac,ogg,m4a,wma
    chunk:
      size: 5242880
      min-file-size: 10485760
      task-expire-hours: 24
    presigned:
      upload-expire-minutes: 60
      download-expire-hours: 24
    quick-upload:
      enabled: true
    concurrent:
      max-uploads-per-user: 5

app:
  upload:
    path: uploads
    max-file-size: 100MB
    max-request-size: 100MB
  pagination:
    default-page-size: 20
    max-page-size: 100

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
      base-path: /actuator
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
  health:
    livenessState:
      enabled: true
    readinessState:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true

logging:
  level:
    root: INFO
    com.sg.nusiss.social: INFO
    org.springframework.web: INFO
    org.springframework.messaging: INFO
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
    file: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
  file:
    name: /app/logs/social-service.log
    max-size: 100MB
    max-history: 30
    total-size-cap: 1GB
EOF
}

# 更新其他服务配置
update_shopping_config() {
    log_info "更新购物服务配置..."
    # 类似地更新其他服务的配置
}

update_forum_config() {
    log_info "更新论坛服务配置..."
    # 类似地更新其他服务的配置
}

update_developer_config() {
    log_info "更新开发者服务配置..."
    # 类似地更新其他服务的配置
}

# 主函数
main() {
    log_info "开始更新生产环境配置..."
    update_prod_configs
    log_success "配置更新完成！"
}

# 运行主函数
main "$@"
