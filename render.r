#!/usr/bin/env r

rmarkdown::run(
  "index.Rmd",
  shiny_args = list(port = 3838, host = "0.0.0.0"),
  render_args = list(quiet = TRUE)
)
