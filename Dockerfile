FROM ubuntu:16.04
MAINTAINER Neil Venables <neil.venables@cruk.manchester.ac.uk>

RUN apt-get update &&\
            apt-get update -y &&\
            apt-get install build-essential -y &&\
            apt-get install git -y &&\
            apt-get install libtool m4 automake pkg-config -y &&\
            apt-get install libssl-dev libxml2-dev zlib1g-dev libboost-dev pbs-drmaa-dev gperf -y

RUN git clone https://github.com/adaptivecomputing/torque.git -b 6.1.1 /usr/local/6.1.1
WORKDIR /usr/local/6.1.1
RUN ./autogen.sh &&\
    ./configure --enable-drmaa &&\
    make &&\
    make install

ENV HOSTNAME master
COPY ./scripts/set_hostname.sh /

# Configure local Torque
RUN ldconfig &&\
    /set_hostname.sh &&\
    echo "$HOSTNAME" > /var/spool/torque/server_name &&\
    echo "y" | pbs_server -t create &&\
    sleep 2 &&\
    trqauthd &&\
    qmgr -c "set server acl_hosts=$HOSTNAME" &&\
    qmgr -c "set server scheduling=true" &&\
    qmgr -c "create queue batch queue_type=execution" &&\
    qmgr -c "set queue batch started=true" &&\
    qmgr -c "set queue batch enabled=true" &&\
    qmgr -c "set queue batch resources_default.nodes=1" &&\
    qmgr -c "set queue batch resources_default.walltime=3600" &&\
    qmgr -c "set server default_queue=batch" &&\
    qmgr -c "set server keep_completed = 10" &&\
    echo "$HOSTNAME np=1" > /var/spool/torque/server_priv/nodes &&\
    printf "\$pbsserver $HOSTNAMEt \n\$logevent 255" > /var/spool/torque/mom_priv/config

RUN adduser --disabled-password --gecos '' batchuser
COPY ./scripts/startenv.sh /

RUN apt-get install environment-modules wget unzip default-jre -y
WORKDIR /usr/local/


RUN echo "source /etc/profile.d/modules.sh" >> /root/.bashrc
RUN echo "alias qsub='qsub -P batchuser'" >> /root/.bashrc

RUN wget --no-check-certificate https://repo.continuum.io/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh && \
    bash Miniconda3-4.6.14-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-4.6.14-Linux-x86_64.sh
ENV PATH /opt/conda/bin:${PATH}
ENV LANG C.UTF-8

WORKDIR /
COPY setup.py setup.py
RUN pip install -e .
COPY nispat/ nispat
WORKDIR /nispat
COPY test_normative_modeling/ test_normative_modeling
WORKDIR /
RUN chmod -R 777 /nispat/*
ENTRYPOINT /startenv.sh && /bin/bash
