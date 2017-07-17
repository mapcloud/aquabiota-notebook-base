# -*- mode: ruby -*-
# vi: set ft=ruby :

# MODIFIED FROM: https://github.com/ContinuumIO/docker-images/blob/master/anaconda3/Dockerfile
FROM ubuntu:16.04

LABEL maintainer "Aquabiota Solutions AB <mapcloud@aquabiota.se>"

ARG DEBIAN_FRONTEND=noninteractive

USER root
# https://hub.docker.com/r/_/debian/
RUN apt-get update && apt-get install -y locales sudo && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.utf8

# Configure environment
ENV NB_USER aqua
ENV NB_UID 1000
ENV HOME /home/$NB_USER
ENV CONDA_DIR $HOME/conda
ENV PATH $CONDA_DIR/bin:$PATH
ENV SHELL /bin/bash
ENV NOTEBOOK_DIR $HOME/workspace/notebooks
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV JUPYTER_CONFIG_DIR $HOME/.ipython/profile_default/


# Create jovyan user with UID=1000 and in the 'users' group
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER $CONDA_DIR

#RUN adduser --disabled-password --gecos '' $NB_USER && \
#    adduser $NB_USER sudo && \
#    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
##########################

# Install all OS dependencies for fully functional notebook server
RUN apt-get update --fix-missing && \
    apt-get -yq dist-upgrade && \
    apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    git \
    jed \
    build-essential \
    fonts-liberation \
    lmodern \
    pandoc \
    python-dev \
    texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-generic-recommended \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-xetex \
    vim \
    unzip \
    p7zip-full \
    # from https://github.com/ContinuumIO/docker-images/blob/master/anaconda3/Dockerfile
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    # Solving installation-of-package-devtools-had-non-zero-exit-status when R-Kernel is used
    libssl-dev libcurl4-gnutls-dev libxml2-dev

RUN echo 'export PATH=/home/aqua/conda/bin:$PATH' > /etc/profile.d/conda.sh

RUN apt-get install -y curl grep sed dpkg && \
    TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb && \
    apt-get clean


#
#RUN mkdir -p $CONDA_DIR && \
    #mkdir -p $JUPYTER_CONFIG_DIR
USER $NB_USER

RUN mkdir $HOME/workspace
WORKDIR $HOME/workspace


RUN mkdir -p $NOTEBOOK_DIR
#

RUN cd $HOME
RUN wget --quiet https://repo.continuum.io/archive/Anaconda3-4.4.0-Linux-x86_64.sh -O $HOME/anaconda.sh && \
    /bin/bash $HOME/anaconda.sh -f -b -p $CONDA_DIR && \
    rm $HOME/anaconda.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda update -y --all && \
    conda clean -tipsy

# amasing requirements
RUN conda install -y bcrypt passlib
RUN conda install -y -c conda-forge gdal geopy 'folium=0.3.0' rasterio 

# setting-up as default the conda-forge channel.
#RUN conda config --system --add channels conda-forge && \
#    conda config --system --set auto_update_conda false

# installing jupyterlab from conda-forge
RUN conda install -y -c conda-forge jupyterlab jupyterhub


# The following line will update all the conda packages to the latest version
# using the conda-forge channel. When in production better to set up
# directly with version numbers.
RUN conda update -y --all

# Installing pip requirements not available through conda
# COPY pip-requirements.txt /tmp/
RUN pip install s2sphere pyorient
#
#--requirement /tmp/pip-requirements.txt

RUN ipython profile create && echo $(ipython locate)
#COPY ipython_config.py $JUPYTER_CONFIG_DIR
#COPY ipython_config.py $(ipython locate)/profile_default

USER root
## Make sure that notebooks is the current WORKDIR
WORKDIR $HOME

# # Clean up APT when done.
#RUN apt-get clean && rm -rf /var/lib/apt/lists/* /var/tmp/*

ENTRYPOINT [ "/usr/bin/tini", "--" ]
CMD ["/bin/bash", "-c"]
USER $NB_USER
