# docker manifest inspect ghcr.io/luomus/base-r-image:main -v | jq '.Descriptor.digest'
FROM ghcr.io/luomus/base-r-image@sha256:c35f0d5795df1052c1c7b303273429f45139b058ea1d280a7879c27ee46b59c7

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
