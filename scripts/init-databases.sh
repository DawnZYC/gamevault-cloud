#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- 创建认证服务数据库
    CREATE DATABASE gamevault_auth;
    GRANT ALL PRIVILEGES ON DATABASE gamevault_auth TO $POSTGRES_USER;
    
    -- 创建社交服务数据库
    CREATE DATABASE gamevault_social;
    GRANT ALL PRIVILEGES ON DATABASE gamevault_social TO $POSTGRES_USER;
    
    -- 创建购物服务数据库
    CREATE DATABASE gamevault_shopping;
    GRANT ALL PRIVILEGES ON DATABASE gamevault_shopping TO $POSTGRES_USER;
    
    -- 创建论坛服务数据库
    CREATE DATABASE gamevault_forum;
    GRANT ALL PRIVILEGES ON DATABASE gamevault_forum TO $POSTGRES_USER;
    
    -- 创建开发者服务数据库
    CREATE DATABASE gamevault_developer;
    GRANT ALL PRIVILEGES ON DATABASE gamevault_developer TO $POSTGRES_USER;
EOSQL

echo "Multiple databases created successfully!"
