## Modified from https://github.com/rocker-org/rocker-versioned2/blob/caff65d9b31327e0662633860c54ae2cc28bc60f/dockerfiles/Dockerfile_r-ver_4.1.0
FROM ubuntu:20.04@sha256:0e0402cd13f68137edb0266e1d2c682f217814420f2d43d300ed8f65479b14fb

ENV R_VERSION=4.2.3
ENV TERM=xterm
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV R_HOME=/usr/local/lib/R
ENV CRAN=https://packagemanager.rstudio.com/all/__linux__/focal/latest
ENV TZ=Etc/UTC

COPY install_R.sh install_R.sh

RUN /install_R.sh

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl \
      libcurl4-openssl-dev \
      libssl-dev \
      libz-dev \
      pandoc \
 && apt-get autoremove -y \
 && apt-get autoclean -y \
 && rm -rf /var/lib/apt/lists/*

COPY renv.lock renv.lock

RUN R -e "install.packages('renv')" \
 && R -e "renv::restore()"

HEALTHCHECK --interval=1m --timeout=10s \
  CMD curl -sfI -o /dev/null 0.0.0.0:3838 || exit 1

ENV  HOME /home/user
ENV  OPENBLAS_NUM_THREADS 1

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY index.Rmd /home/user/index.Rmd

RUN  mkdir -p /home/user/data \
  && chgrp -R 0 /home/user \
  && chmod -R g=u /home/user /etc/passwd

WORKDIR /home/user

USER 1000

EXPOSE 3838

ENTRYPOINT ["entrypoint.sh"]

CMD ["R", "-e", "rmarkdown::run('index.Rmd', shiny_args = list(port = 3838, host = '0.0.0.0'))"]
