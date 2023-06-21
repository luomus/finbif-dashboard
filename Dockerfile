FROM ghcr.io/luomus/base-r-image@sha256:72e1ff6c79f1ac492cd9f18ee7cf45df783ad788ab0567bca527bf459b7c6afd

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
