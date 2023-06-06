FROM bellsoft/alpaquita-linux-gcc@sha256:21078034b252905a53809fa6407e5834a2e94f21ab6bd5de59d16f640c2f7338 as verfy

ARG FPR=70092656FB28DBB76C3BB42E89619023B6601234
ARG GPG_KEY_URL=https://github.com/slurmorg/build-containers-trusted/raw/main/key.gpg
ARG ROOTFS_URL=https://github.com/slurmorg/build-containers-trusted/raw/main/rootfs.tar.gz
ARG MAVEN_URL=https://github.com/slurmorg/build-containers-trusted/raw/main/apache-maven-3.9.1-bin.tar.gz
ARG TOMCAT_URL=https://github.com/slurmorg/build-containers-trusted/raw/main/apache-tomcat-10.1.7.tar.gz

ENV HOME=/usr/app
RUN mkdir -p $HOME
WORKDIR $HOME

RUN apk add --no-cache curl gnupg tar

RUN curl -sLJO ${GPG_KEY_URL} \
    && if [ $(gpg --with-colons --import-options show-only --import key.gpg | awk -F: '$1 == "fpr" {print $10;}') != ${FPR} ]; then exit 1; fi

RUN curl -sLJO --compressed ${ROOTFS_URL} \
    && curl -sLJO --compressed ${ROOTFS_URL}.sha512 \
    && curl -sLJO --compressed ${ROOTFS_URL}.sha512.asc \
    && sha512sum -c rootfs.tar.gz.sha512

RUN curl -sLJO --compressed ${MAVEN_URL} \
    && curl -sLJO --compressed ${MAVEN_URL}.sha512 \
    && curl -sLJO --compressed ${MAVEN_URL}.sha512.asc \
    && sha512sum -c apache-maven-3.9.1-bin.tar.gz.sha512

RUN curl -sLJO --compressed ${TOMCAT_URL} \
    && curl -sLJO --compressed ${TOMCAT_URL}.sha512 \
    && curl -sLJO --compressed ${TOMCAT_URL}.sha512.asc \
    && sha512sum -c apache-tomcat-10.1.7.tar.gz.sha512

RUN gpg --import key.gpg
RUN gpg --batch --verify rootfs.tar.gz.sha512.asc rootfs.tar.gz.sha512
RUN gpg --batch --verify apache-maven-3.9.1-bin.tar.gz.sha512.asc apache-maven-3.9.1-bin.tar.gz.sha512
RUN gpg --batch --verify apache-tomcat-10.1.7.tar.gz.sha512.asc apache-tomcat-10.1.7.tar.gz.sha512

RUN mkdir rootfs && tar zxf rootfs.tar.gz -C rootfs
RUN mkdir maven && tar zxf apache-maven-3.9.1-bin.tar.gz -C maven --strip-components=1
RUN mkdir tomcat && tar zxf apache-tomcat-10.1.7.tar.gz -C tomcat --strip-components=1

FROM scratch as buld

ENV PATH=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64/bin:/opt/bin/maven/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8:en
ENV JAVA_HOME=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64
ENV MAVEN_HOME=/opt/bin/maven

COPY --from=verfy /usr/app/rootfs /
COPY --from=verfy /usr/app/maven /opt/bin/maven

ENV HOME=/usr/app
RUN mkdir -p $HOME
WORKDIR $HOME

COPY pom.xml pom.xml
COPY src src

RUN mvn verify

FROM scratch as final

ENV PATH=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64/bin:/opt/bin/tomcat/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8:en
ENV JAVA_HOME=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64
ENV CATALINA_HOME=/opt/bin/tomcat

COPY --from=verfy /usr/app/rootfs /
COPY --from=verfy /usr/app/tomcat /opt/bin/tomcat
RUN rm $CATALINA_HOME/webapps/* -rf
COPY --from=buld /usr/app/target/api.war $CATALINA_HOME/webapps/ROOT.war

EXPOSE 8080

CMD [ "catalina.sh", "run" ]