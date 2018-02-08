# Variant of the rocker/shiny file -- edits include installing packages
# https://github.com/rocker-org/shiny/blob/master/Dockerfile

FROM rocker/rstudio:3.4.3

# IHME-specific folder configuration
# Make symlink for folders in /home (Singularity doesn't bind on /home contents because /home already exists from RStudio's side)
RUN ln -s /snfs1 /home/j

# Initiate bind mount points for IHME standard mounts
RUN for i in /share /ihme /share/code /ihme/code /share/gbd /ihme/gbd /homes /snfs1 /snfs2 /usr/local/UGE; \
    do \
        mkdir "$i"; \
    done

# Begin library builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    gdebi-core \
    pandoc \
    pandoc-citeproc \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    default-libmysqlclient-dev \
    libmariadb2 \
    libmariadb-client-lgpl-dev \
    curl \
    libssl-dev \
    libxml2-dev \
    libgdal-dev gdal-bin libproj-dev \
    libgl1-mesa-dri libglu1-mesa-dev \
    git \
    x11-xserver-utils \
    x11vnc \
    mesa-common-dev \
    libssh2-1-dev \
    libtiff5-dev \
    gcc \
    ssh \
    libarmadillo-dev \
    libgsl0-dev \
    lsof

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update --fix-missing && apt-get install -y wget bzip2 ca-certificates \
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    git mercurial subversion

RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-4.3.27-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

RUN apt-get install -y curl grep sed dpkg && \
    TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb && \
    apt-get clean

ENV PATH /opt/conda/bin:$PATH

### Intel python with optimized libraries + tensorflow
ENV ACCEPT_INTEL_PYTHON_EULA=yes
RUN conda update -y -q conda \
 && conda config --add channels intel \
 && conda install -y -q intelpython3_full python=3
RUN conda install -y -q pymc3


# Download and install shiny server
RUN wget --no-verbose https://s3.amazonaws.com/rstudio-shiny-server-os-build/ubuntu-12.04/x86_64/VERSION -O "version.txt" && \
    VERSION=$(cat version.txt)  && \
    wget --no-verbose "https://s3.amazonaws.com/rstudio-shiny-server-os-build/ubuntu-12.04/x86_64/shiny-server-$VERSION-amd64.deb" -O ss-latest.deb && \
    gdebi -n ss-latest.deb && \
    rm -f version.txt ss-latest.deb

# Set timezone to PST
ENV TZ="PST"

## Edit Rstudio configuration file -- no session timeout
RUN printf '# R Session Configuration File \n session-timeout-minutes=0 \n' > /etc/rstudio/rsession.conf

## Edit privileges on /run for conversion to Singularity
RUN chmod 777 /etc
RUN chmod 777 /var
RUN chmod 777 /var/run
RUN chmod 777 /run
RUN chmod 777 /run/rstudio-server

RUN mkdir /var/run/s6
RUN chmod 777 /var/run/s6
RUN mkdir /var/run/s6/container_environment
RUN chmod 777 /var/run/s6/container_environment
RUN touch /var/run/s6/container_environment/STATATMP
RUN chmod 777 /var/run/s6/container_environment/STATATMP

RUN rm /etc/localtime
ENV TZ=America/Los_Angeles
RUN sudo ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

# Add UGE dev and prod to PATH (to use qstat, qsub, etc.)
## RStudio uses the environment from
ENV PATH="/usr/local/UGE/bin/lx-amd64:/usr/lib/rstudio-server/bin:${PATH}:/usr/conda/bin:${PATH}"
ENV SGE_ROOT="/usr/local/UGE"
RUN printf '\nPATH=/usr/local/UGE/bin/lx-amd64:/usr/lib/rstudio-server/bin:${PATH}\nSGE_ROOT=/usr/local/UGE\nSGE_CELL=ihme\nTZ=America/Los_Angeles\nOMP_NUM_THREADS=1\n' >> /usr/local/lib/R/etc/Renviron

ENV TF_CPP_MIN_LOG_LEVEL=2
ENV TENSORFLOW_PYTHON='/opt/conda/bin'
ENV PYTHON_BIN_PATH='/opt/conda/bin'
# ENV PATH="/opt/microsoft/ropen/3.4.2/lib64/R/bin:/usr/local/UGE/bin/lx-amd64:/usr/conda/bin:${PATH}"
ENV DRMAA_LIBRARY_PATH=/usr/local/UGE/lib/lx-amd64/libdrmaa.so.1.0

### Install Tensorflow API in R
RUN R -e 'install.packages(c("tensorflow"),repos = "https://cran.revolutionanalytics.com")' 
ENV TF_CPP_MIN_LOG_LEVEL=2
RUN  export TF_CPP_MIN_LOG_LEVEL=2
RUN R -e "library(tensorflow) ; sess = tf\$Session(); hello <- tf\$constant('Hello, TensorFlow'); sess\$run(hello)"

# R kernel
RUN R -e "options(unzip='internal') ; install.packages('devtools'); devtools::install_github('IRkernel/IRkernel')"

# Install Keras
RUN pip install keras
RUN R -e "install.packages('keras')" 

## Edit privileges on /run for conversion to Singularity
## parallel chmod
# RUN cd 
# RUN find * -print0 | xargs -0 -P 4 chmod 777
# RUN cd 
# RUN chmod -R 777
RUN chmod 777 /etc
RUN chmod 777 /var
RUN chmod 777 /var/run
RUN chmod 777 /run

WORKDIR /user/bin
RUN chmod 777 /user/bin
RUN chmod -R 777 /opt/conda/
RUN chmod -R 777 /usr/

# CMD ["/usr/bin/R"]


