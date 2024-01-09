#!/usr/bin/env Rscript

if (Sys.getenv("BRANCH") == "main") {

    cat(
      sprintf(
        '<script defer data-domain="%s" src="%s"></script>\n',
        Sys.getenv("HOST"),
        "https://plausible.io/js/script.js"
      ),
      file = "plausible.html",
      append = TRUE
    )

}

rmarkdown::run(
  "index.Rmd",
  shiny_args = list(port = 3838, host = "0.0.0.0"),
  render_args = list(quiet = TRUE)
)
