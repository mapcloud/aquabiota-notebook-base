# -*- mode: ruby -*-
# vi: set ft=ruby :

# docker run -d -v /your/local/dir/to/data:/home/aqua/workspace/data -v /your/local/dir/to/notebooks:/home/aqua/workspace/notebooks --name jupyter-base -p 8889:8889 aquabiota/notebook-base jupyter notebook --ip='*' --port=8889  --no-browser

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
ENV AQUABIOTA_USER user.name
ENV NB_UID 1000
ENV HOME /home/$NB_USER
ENV CONDA_DIR $HOME/conda
ENV PATH $CONDA_DIR/bin:$PATH
ENV SHELL /bin/bash
ENV WORKSPACE_DIR $HOME/workspace
ENV DATA_DIR $WORKSPACE_DIR/data
ENV AQUABIOTA_GIT_DIR $WORKSPACE_DIR/git
# ENV NOTEBOOK_DIR $WORKSPACE_DIR/notebooks
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV JUPYTER_CONFIG_DIR $HOME/.ipython/profile_default/
# Environments for gdal to work
ENV GDAL_DATA $CONDA_DIR/share/gdal/
ENV GEOS_DIR $CONDA_DIR


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
    libssl-dev libcurl4-gnutls-dev libxml2-dev \
    # solving Ubuntu Missing add-apt-repository command
    # http://lifeonubuntu.com/ubuntu-missing-add-apt-repository-command/
    software-properties-common python-software-properties

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
# Create the workspace and workspace for data
RUN mkdir -p $DATA_DIR
WORKDIR $WORKSPACE_DIR

# RUN mkdir -p $NOTEBOOK_DIR
RUN mkdir -p $AQUABIOTA_GIT_DIR
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
RUN conda install -y -c conda-forge libgdal gdal geopy folium rasterio \
    ipyleaflet bqplot cmocean cartopy iris shapely pyproj geopandas

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
# make sure ipython will know where to find the git packages.

COPY ipython_config.py $JUPYTER_CONFIG_DIR
#COPY ipython_config.py $(ipython locate)/profile_default

USER root
## Make sure that notebooks are in the current WORKDIR
WORKDIR $HOME
# Ensure workspace belongs to user
# Ensure access to .local
RUN chown -R $NB_USER:users $WORKSPACE_DIR && \
    chown -R $NB_USER:users $HOME/.local

# # Clean up APT when done.
#RUN apt-get clean && rm -rf /var/lib/apt/lists/* /var/tmp/*

ENTRYPOINT [ "/usr/bin/tini", "--" ]
CMD ["/bin/bash", "-c"]
USER $NB_USER
