FROM ghcr.io/luomus/base-r-image@sha256:b61f78d380e35c41b4161a55b56b4ba2c6ba9baeb5837df9504d141e1a8cdce7

ENV FINBIF_USER_AGENT=https://github.com/luomus/finbif-dashboard
ENV FINBIF_USE_PRIVATE_API=true

COPY renv.lock /home/user/renv.lock
COPY index.Rmd /home/user/index.Rmd
COPY api.R /home/user/api.R
COPY collections.R /home/user/collections.R
COPY favicon.ico /home/user/favicon.ico
COPY plausible.html /home/user/plausible.html
COPY render.r /home/user/render.r

RUN  R -e "renv::restore()" \
  && permissions.sh
