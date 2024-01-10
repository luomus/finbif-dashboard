FROM ghcr.io/luomus/base-r-image@sha256:0f9cc984724cfc5a268ecc9bfea057fc8f6ef2251f7dcf96baa173de4579e711

ENV FINBIF_USER_AGENT=https://github.com/luomus/finbif-dashboard
ENV FINBIF_USE_PRIVATE_API=true

COPY renv.lock /home/user/renv.lock

RUN R -s -e "renv::restore()"

COPY index.Rmd /home/user/index.Rmd
COPY api.R /home/user/api.R
COPY collections.R /home/user/collections.R
COPY favicon.ico /home/user/favicon.ico
COPY plausible.html /home/user/plausible.html
COPY translation.json /home/user/translation.json
COPY navbar.html /home/user/navbar.html
COPY styles.css /home/user/styles.css
COPY render.r /home/user/render.r
COPY finland.rds /home/user/finland.rds
COPY bio-provinces.rds /home/user/bio-provinces.rds

RUN permissions.sh
