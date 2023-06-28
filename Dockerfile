FROM ghcr.io/luomus/base-r-image@sha256:bfc65b835b503a235459716a9eb8afefb2bec94effdb19e69573885b898b00e8

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
