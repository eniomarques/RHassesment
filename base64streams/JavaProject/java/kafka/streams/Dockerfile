FROM centos:7

RUN yum -y update && yum -y install java-11-openjdk-headless openssl && yum -y clean all

# Set JAVA_HOME env var
ENV JAVA_HOME /usr/lib/jvm/java

ARG version=latest
ENV VERSION ${version}

COPY ./scripts/ /bin
COPY ./src/main/resources/log4j2.properties /bin/log4j2.properties

ADD target/java-kafka-streams-1.0-SNAPSHOT.jar /

RUN ["chmod", "+x", "/bin/run.sh"]

CMD ["/bin/run.sh", "/java-kafka-streams-1.0-SNAPSHOT.jar"]
