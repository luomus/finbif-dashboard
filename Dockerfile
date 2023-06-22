FROM ghcr.io/luomus/base-r-image@sha256:789f0fca5d335e8b452f02eec43bced9aabb69aafae0b02bbcdf845e1f49e8fe

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
