library(logger, quietly = TRUE)
library(plumber, quietly = TRUE)
library(tictoc, quietly = TRUE)

if (!dir.exists("logs")) dir.create("logs")

log_appender(appender_tee(tempfile("plumber_", "logs", ".log")))

convert_empty <- function(x) switch(paste0(".", x), . = "-", x)

p <- plumb("api.R")

p[["registerHooks"]](
  list(
    preroute = function() tic(),
    postroute = function(req, res) {

      end <- toc(quiet = TRUE)

      log_fn <- log_info

      if (res[["status"]] >= 400L) log_fn <- log_error

      log_fn(
        paste0(
          '{convert_empty(req$REMOTE_ADDR)} ',
          '"{convert_empty(req$HTTP_USER_AGENT)}" ',
          '{convert_empty(req$HTTP_HOST)} ',
          '{convert_empty(req$REQUEST_METHOD)} ',
          '{convert_empty(req$PATH_INFO)} ',
          '{convert_empty(res$status)} ',
          '{round(end$toc - end$tic, digits = getOption("digits", 5L))}'
        )
      )

    }
  )
)

p <- pr_set_docs(p, FALSE)

pr_run(p, host = "0.0.0.0", port = 8000L)
