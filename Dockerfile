# -*- mode: ruby -*-
# vi: set ft=ruby :

# MODIFIED FROM: https://github.com/ContinuumIO/docker-images/blob/master/anaconda3/Dockerfile
FROM ubuntu:16.04

LABEL maintainer "Aquabiota Solutions AB <mapcloud@aquabiota.se>"

ARG DEBIAN_FRONTEND=noninteractive

# https://hub.docker.com/r/_/debian/
RUN apt-get update && apt-get install -y locales sudo && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.utf8


# Replace 1000 with your user / group id
RUN export uid=1000 gid=1000 && \
    mkdir -p /home/amasing && \
    echo "amasing:x:${uid}:${gid}:amasing,,,:/home/amasing:/bin/bash" >> /etc/passwd && \
    echo "amasing:x:${uid}:" >> /etc/group && \
    echo "amasing ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/amasing && \
    chmod 0440 /etc/sudoers.d/amasing && \
    chown ${uid}:${gid} -R /home/amasing


RUN apt-get update --fix-missing && \
    apt-get -yq dist-upgrade && \
    apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    git \
    # from https://github.com/ContinuumIO/docker-images/blob/master/anaconda3/Dockerfile
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    # Solving installation-of-package-devtools-had-non-zero-exit-status when R-Kernel is used
    libssl-dev libcurl4-gnutls-dev libxml2-dev


RUN apt-get install -y curl grep sed dpkg && \
    TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb && \
    apt-get clean

# conda installation
ENV HOME /home/amasing
ENV CONDA_DIR $HOME/conda
ENV PATH $CONDA_DIR/bin:$PATH
ENV SHELL /bin/bash
ENV NOTEBOOK_DIR $HOME/notebooks
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV JUPYTER_CONFIG_DIR $HOME/.ipython/profile_default/

#
#RUN mkdir -p $CONDA_DIR && \
    #mkdir -p $JUPYTER_CONFIG_DIR
RUN mkdir -p $NOTEBOOK_DIR
#
RUN echo 'export PATH=/home/amasing/conda/bin:$PATH' > /etc/profile.d/conda.sh

### USER ##################################

USER amasing
RUN cd $HOME
RUN wget --quiet https://repo.continuum.io/archive/Anaconda3-4.4.0-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /home/amasing/conda && \
    rm ~/anaconda.sh

RUN conda install -y bcrypt passlib

# setting-up as default the conda-forge channel.
#RUN conda config --system --add channels conda-forge && \
#    conda config --system --set auto_update_conda false

# installing jupyterlab from conda-forge
RUN conda install -y -c conda-forge gdal jupyterlab \
  geopy folium=0.3.0 rasterio

# The following line will update all the conda packages to the latest version
# using the conda-forge channel. When in production better to set up
# directly with version numbers.
RUN conda update -y --all

    # && \
    # conda clean -tipsy

# Installing pip requirements not available through conda
# COPY pip-requirements.txt /tmp/
RUN pip install s2sphere pyorient
#
#--requirement /tmp/pip-requirements.txt

RUN ipython profile create && echo $(ipython locate)
#COPY ipython_config.py $JUPYTER_CONFIG_DIR
#COPY ipython_config.py $(ipython locate)/profile_default

## Make sure that notebooks is the current WORKDIR
WORKDIR $HOME

# # Clean up APT when done.
#RUN apt-get clean && rm -rf /var/lib/apt/lists/* /var/tmp/*

ENTRYPOINT [ "/usr/bin/tini", "--" ]
CMD ["/bin/bash", "-c"]
