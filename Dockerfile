FROM ghcr.io/luomus/base-r-image@sha256:b28f78a79dd9593323f5783c449a8060ddc0149d4a010002f25fef3f8e213a69

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
