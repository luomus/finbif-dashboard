# docker manifest inspect ghcr.io/luomus/base-r-image:main -v | jq '.Descriptor.digest'
FROM ghcr.io/luomus/base-r-image@sha256:a2bf677161e832d94a43682a5ad0d450924a8ae4867a44b3611709d058d65b60

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
