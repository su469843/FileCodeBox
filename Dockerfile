# 使用多平台支持的 Python 基础镜像 (注意：python:3.9.5-slim-buster 可能对 armv7 支持有限)
FROM python:3.9-slim-bullseye AS builder

# 元数据标签
LABEL author="Lan"
LABEL email="xzu@live.com"
LABEL description="FileCodeBox Application"
LABEL version="1.0.0"

# 设置时区为亚洲/上海
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo 'Asia/Shanghai' > /etc/timezone

# 安装系统依赖和构建工具 (解决 gcc 缺失问题)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    make \
    libffi-dev \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制依赖文件 (利用 Docker 缓存层)
COPY requirements.txt .

# 升级 pip 并安装依赖
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


# 第二阶段：生产环境
FROM python:3.9-slim-bullseye

# 设置元数据
LABEL author="Lan"
LABEL email="xzu@live.com"
LABEL description="FileCodeBox Application - Production"
LABEL version="1.0.0"

# 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo 'Asia/Shanghai' > /etc/timezone

# 创建非 root 用户运行应用 (增强安全性)
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制已安装的依赖
COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# 复制应用代码
COPY . .

# 删除不必要的文件和目录，减少镜像体积
RUN rm -rf docs fcb-fronted tests .github .git* Dockerfile.dockerignore README.md && \
    find . -name "*.pyc" -delete && \
    find . -name "__pycache__" -delete

# 更改文件所有权给非 root 用户
RUN chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 12345

# 健康检查
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:12345/api/health || exit 1

# 启动应用
CMD ["python", "main.py"]
