# =============================================================================
#  BTL De 01 - Anh dung chung cho ca 4 "may ao" (masternode + 3 datanode)
#     Hadoop 3.2.2 (HDFS + Yarn + MapReduce)  |  Spark 3.1.2 (+ PySpark)
#     Pig 0.17.0  |  Flume 1.11.0  |  HBase 2.5.16 (+ ZooKeeper di kem)
#     JDK 8 (javac cho MapReduce Java)  |  Python 3.8  |  sqlite3
#  Vai tro tung may do bien NODE_ROLE trong docker-compose.yml quyet dinh.
# =============================================================================
FROM ubuntu:20.04
LABEL org.opencontainers.image.source="https://github.com/ariushieu/ecommerce-bigdata-pipeline" \
      org.opencontainers.image.description="BTL De 01 - Hadoop/Spark/Pig/Flume/HBase node"

ARG HADOOP_VERSION=3.2.2
ARG SPARK_VERSION=3.1.2
ARG PIG_VERSION=0.17.0
ARG FLUME_VERSION=1.11.0
ARG HBASE_VERSION=2.5.16

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Ho_Chi_Minh \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# ---- 1. Cac goi he thong ----------------------------------------------------
#  python3 3.8: PySpark 3.1.2 chi ho tro toi Python 3.9 nen giu Ubuntu 20.04
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-8-jdk \
        openssh-server openssh-client \
        curl wget tar gzip unzip \
        netcat-openbsd \
        procps net-tools iputils-ping tzdata \
        nano vim less sudo \
        python3 python-is-python3 \
        sqlite3 \
    && ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# ---- 2. Nguoi dung hadoop + SSH ---------------------------------------------
#  Anh KHONG chua khoa SSH nao (repo cong khai, anh day len GHCR). Khoa nam o
#  ./ssh-key tren may tung thanh vien (scripts/setup.ps1 / scripts/setup.sh sinh ra), gan vao
#  /ssh-key luc chay; entrypoint.sh cai vao dung cho:
#   - id_ed25519           : 4 may dung chung -> ssh qua lai khong mat khau;
#                            Windows cung dung khoa nay de "ssh may1".."ssh may4"
#   - ssh_host_ed25519_key : host key co dinh -> build lai anh khong bi bao
#                            "REMOTE HOST IDENTIFICATION HAS CHANGED"
RUN useradd -m -s /bin/bash hadoop \
    && echo 'hadoop:hadoop' | chpasswd \
    && echo 'hadoop ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && mkdir -p /var/run/sshd \
    && rm -f /etc/ssh/ssh_host_* \
    && echo 'HostKey /etc/ssh/ssh_host_ed25519_key' >> /etc/ssh/sshd_config \
    && echo 'PrintLastLog no' >> /etc/ssh/sshd_config \
    && echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config \
    && rm -f /etc/update-motd.d/* /etc/legal

USER hadoop
RUN mkdir -p /home/hadoop/.ssh \
    && printf 'Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null\n    LogLevel ERROR\n' \
        > /home/hadoop/.ssh/config \
    && chmod 700 /home/hadoop/.ssh && chmod 600 /home/hadoop/.ssh/config

# ---- 3. Cai cac cong cu (ban cai tai truoc o ./downloads, xem fetch.sh) -----
#  Gan ./downloads vao luc build (bind mount) thay vi COPY -> file nen khong bi
#  giu lai trong anh, anh nhe hon ~1,2 GB.
WORKDIR /home/hadoop

RUN --mount=type=bind,source=downloads,target=/dl set -eux; tar -xzf /dl/hadoop-${HADOOP_VERSION}.tar.gz; mv hadoop-${HADOOP_VERSION} hadoop; rm -rf hadoop/share/doc

RUN --mount=type=bind,source=downloads,target=/dl set -eux; tar -xzf /dl/spark-${SPARK_VERSION}-bin-hadoop3.2.tgz; mv spark-${SPARK_VERSION}-bin-hadoop3.2 spark

#  Flume 1.11 kem guava-11, xung dot voi guava-27 cua Hadoop 3.2.2 (HDFS sink
#  bao NoSuchMethodError) -> xoa ban cua Flume, dung ban cua Hadoop.
RUN --mount=type=bind,source=downloads,target=/dl set -eux; tar -xzf /dl/apache-flume-${FLUME_VERSION}-bin.tar.gz; mv apache-flume-${FLUME_VERSION}-bin flume; rm -rf flume/docs; rm -f flume/lib/guava-*.jar

RUN --mount=type=bind,source=downloads,target=/dl set -eux; tar -xzf /dl/hbase-${HBASE_VERSION}-hadoop3-bin.tar.gz; mv hbase-${HBASE_VERSION}-hadoop3 hbase; rm -rf hbase/docs

RUN --mount=type=bind,source=downloads,target=/dl set -eux; tar -xzf /dl/pig-${PIG_VERSION}.tar.gz; mv pig-${PIG_VERSION} pig; rm -rf pig/docs pig/src pig/test

ENV HADOOP_HOME=/home/hadoop/hadoop \
    HADOOP_CONF_DIR=/home/hadoop/hadoop/etc/hadoop \
    SPARK_HOME=/home/hadoop/spark \
    PIG_HOME=/home/hadoop/pig \
    PIG_CLASSPATH=/home/hadoop/hadoop/etc/hadoop \
    FLUME_HOME=/home/hadoop/flume \
    HBASE_HOME=/home/hadoop/hbase \
    PYSPARK_PYTHON=python3
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$PIG_HOME/bin:$FLUME_HOME/bin:$HBASE_HOME/bin:/home/hadoop/scripts

# ---- 4. Cau hinh ------------------------------------------------------------
COPY --chown=hadoop:hadoop docker/config/hadoop/ $HADOOP_HOME/etc/hadoop/
COPY --chown=hadoop:hadoop docker/config/spark/  $SPARK_HOME/conf/
COPY --chown=hadoop:hadoop docker/config/hbase/  $HBASE_HOME/conf/
COPY --chown=hadoop:hadoop docker/config/flume/  $FLUME_HOME/conf/
COPY --chown=hadoop:hadoop scripts/ /home/hadoop/scripts/

#  File sua tren Windows co the mang CRLF -> doi ve LF cho chac
RUN find $HADOOP_HOME/etc/hadoop $SPARK_HOME/conf $HBASE_HOME/conf $FLUME_HOME/conf /home/hadoop/scripts \
        -maxdepth 1 -type f -exec sed -i 's/\r$//' {} + \
    && chmod +x /home/hadoop/scripts/*.sh \
    && mkdir -p /home/hadoop/hdfs/namenode /home/hadoop/hdfs/datanode /home/hadoop/hdfs/tmp \
                /home/hadoop/hdfs/zookeeper /home/hadoop/flume-data /home/hadoop/src \
                $HADOOP_HOME/logs $HBASE_HOME/logs \
    && chmod 700 /home/hadoop/hdfs/namenode /home/hadoop/hdfs/datanode

#  Bien moi truong cho MOI loai shell: dang nhap, ssh, "su - hadoop -c ..."
USER root
RUN { \
      echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64'; \
      echo 'export HADOOP_HOME=/home/hadoop/hadoop'; \
      echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop'; \
      echo 'export SPARK_HOME=/home/hadoop/spark'; \
      echo 'export PIG_HOME=/home/hadoop/pig'; \
      echo 'export PIG_CLASSPATH=$HADOOP_CONF_DIR'; \
      echo 'export FLUME_HOME=/home/hadoop/flume'; \
      echo 'export HBASE_HOME=/home/hadoop/hbase'; \
      echo 'export PYSPARK_PYTHON=python3'; \
      echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$PIG_HOME/bin:$FLUME_HOME/bin:$HBASE_HOME/bin:/home/hadoop/scripts'; \
    } > /etc/profile.d/btl-env.sh \
    && chmod 644 /etc/profile.d/btl-env.sh \
    && sed -i '1i # Dau file (truoc doan "khong tuong tac thi return") de "ssh may1 <lenh>" cung co PATH\n. /etc/profile.d/btl-env.sh\n' /home/hadoop/.bashrc \
    && echo '. /etc/btl-prompt.sh' >> /home/hadoop/.bashrc \
    && echo 'cd /home/hadoop/src 2>/dev/null' >> /home/hadoop/.bashrc

#  Loi chao khi ssh vao (zz- de chay sau btl-env.sh) + dau nhac co mau
COPY docker/node/welcome.sh /etc/profile.d/zz-btl-welcome.sh
COPY docker/node/prompt.sh  /etc/btl-prompt.sh
COPY docker/node/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /etc/profile.d/zz-btl-welcome.sh /etc/btl-prompt.sh \
    && chmod 644 /etc/profile.d/zz-btl-welcome.sh /etc/btl-prompt.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 2181 8042 8088 9000 9864 9870 16010 16020 16030 18080 19888 41414 44444
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
