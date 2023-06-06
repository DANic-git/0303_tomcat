FROM bellsoft/alpaquita-linux-gcc@sha256:21078034b252905a53809fa6407e5834a2e94f21ab6bd5de59d16f640c2f7338 as verfy

ARG FPR=70092656FB28DBB76C3BB42E89619023B6601234
ARG GPG_KEY_URL=https://raw.githubusercontent.com/slurmorg/build-containers-trusted/main/key.gpg
ARG ROOTFS_URL=https://github.com/slurmorg/build-containers-trusted/raw/main/rootfs.tar.gz
ARG MAVEN_URL=https://github.com/slurmorg/build-containers-trusted/raw/main/apache-maven-3.9.1-bin.tar.gz
ARG TOMCAT_URL=https://github.com/slurmorg/build-containers-trusted/raw/main/apache-tomcat-10.1.7.tar.gz

ENV HOME=/usr/app
RUN mkdir -p $HOME
WORKDIR $HOME

RUN apk add --no-cache curl gnupg

RUN curl -sLJO ${GPG_KEY_URL} \
    && if [ $(gpg --with-colons --import-options show-only --import key.gpg | awk -F: '$1 == "fpr" {print $10;}') != ${FPR} ]; then exit 1; fi

RUN curl -sLJO --compressed ${ROOTFS_URL}