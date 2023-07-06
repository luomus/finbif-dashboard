FROM ghcr.io/luomus/base-r-image@sha256:5d18cfef40c2a5180ee4819f6da689b3b63f3df567340ee49439965363d0b695

COPY renv.lock /home/user/renv.lock
COPY index.Rmd /home/user/index.Rmd
COPY api.R /home/user/api.R
COPY collections.R /home/user/collections.R
COPY favicon.ico /home/user/favicon.ico
COPY plausible.html /home/user/plausible.html

RUN  chgrp -R 0 /home/user \
  && chmod -R g=u /home/user /etc/passwd

RUN  R -e "renv::restore()"

ENV FINBIF_USER_AGENT=https://github.com/luomus/finbif-dashboard
ENV FINBIF_USE_PRIVATE_API=true
