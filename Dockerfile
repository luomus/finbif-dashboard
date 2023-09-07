FROM ghcr.io/luomus/base-r-image@sha256:047e13660472b4e82a2de18b3aca9900edd0ac67ddcf729e71a6c53a29c6c09b

ENV FINBIF_USER_AGENT=https://github.com/luomus/finbif-dashboard
ENV FINBIF_USE_PRIVATE_API=true

COPY renv.lock /home/user/renv.lock
COPY index.Rmd /home/user/index.Rmd
COPY api.R /home/user/api.R
COPY collections.R /home/user/collections.R
COPY favicon.ico /home/user/favicon.ico
COPY plausible.html /home/user/plausible.html
COPY translation.json /home/user/translation.json
COPY lang-selector.html /home/user/lang-selector.html
COPY styles.css /home/user/styles.css
COPY render.r /home/user/render.r

RUN  R -e "renv::restore()" \
  && permissions.sh
