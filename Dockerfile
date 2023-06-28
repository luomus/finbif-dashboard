FROM ghcr.io/luomus/base-r-image@sha256:1284c451bd7c894bc77aa728087648562a9c10a203e688cf81a317aaa6f93de5

COPY renv.lock /home/user/renv.lock
COPY index.Rmd /home/user/index.Rmd
COPY api.R /home/user/api.R
COPY collections.R /home/user/collections.R
COPY favicon.ico /home/user/favicon.ico

RUN  R -e "renv::restore()" \
  && chgrp -R 0 /home/user \
  && chmod -R g=u /home/user /etc/passwd

ENV FINBIF_USER_AGENT=https://github.com/luomus/finbif-dashboard
ENV FINBIF_USE_PRIVATE_API=true
