library(DBI, quietly = TRUE)
library(dplyr, quietly = TRUE)
library(finbif, quietly = TRUE)
library(janitor, quietly = TRUE)
library(RSQLite, quietly = TRUE)
library(tidyr, quietly = TRUE)
library(future, quietly = TRUE)

plan(multisession)

options(
  finbif_use_cache = 1,
  finbif_timeout_offset = .1,
  finbif_hide_progress = TRUE,
  finbif_rate_limit = Inf,
  finbif_max_page_size = 3000L,
  finbif_use_async = FALSE
)

op <- options()

sanitise <- function(x) {

  switch(x, `NULL` = NULL, x)

}

#* @get /record-count
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  filter <- list()

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  future::future({

    options(op)

    db <- dbConnect(SQLite(), "db-cache.sqlite")

    options(finbif_cache_path = db)

    ans <- fb_occurrence(
      filter = filter, select = "record_id", count_only = TRUE
    )

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#* @get /species-count
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  filter <- list()

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  future::future({

    options(op)

    db <- dbConnect(SQLite(), "db-cache.sqlite")

    options(finbif_cache_path = db)

    ans <- fb_occurrence(
      filter = filter,
      select = "species_scientific_name",
      aggregate = "records",
      count_only = TRUE
    )

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#* @get /collection-count
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  filter <- list()

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  future::future({

    options(op)

    db <- dbConnect(SQLite(), "db-cache.sqlite")

    options(finbif_cache_path = db)

    ans <- fb_occurrence(
      filter = filter,
      select = "collection_id",
      aggregate = "records",
      count_only = TRUE
    )

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#* @get /quality-table
#* @serializer rds
function(collection_quality = "NULL", restriction = "NULL", taxa = "NULL", source = "NULL") {

  filter <- list()

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  filter[["collection_quality"]] <- sanitise(collection_quality)

  future::future({

    options(op)

    db <- dbConnect(SQLite(), "db-cache.sqlite")

    options(finbif_cache_path = db)

    ans <-
      fb_occurrence(
        filter = filter,
        select = c(`Verification Status` = "record_quality"),
        aggregate = "records",
        n = "all"
      ) |>
      mutate(
        record_quality = replace_na(`Verification Status`, "Unnassesed")
      ) |>
      group_by(`Verification Status`) |>
      summarise(n_records = sum(n_records), .groups = "drop") |>
      rename(`Number of Records` = n_records) |>
      mutate(
        `Verification Status` = factor(
          `Verification Status`,
          levels = c(
            "Expert verified",
            "Community verified",
            "Unassessed",
            "Uncertain",
            "Erroneous"
          ),
          ordered = TRUE
        )
      ) |>
      arrange(`Verification Status`) |>
      adorn_totals()

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#* @get /occurrence-plot
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  filter <- list()

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  future::future({

    options(op)

    db <- dbConnect(SQLite(), "db-cache.sqlite")

    options(finbif_cache_path = db)

    ans <-
      fb_occurrence(
        filter = filter,
        select = c(Date = "first_load_date", Type = "superrecord_basis"),
        aggregate = "records",
        n = "all"
      ) |>
      mutate(
        Type = case_match(
          Type, "PRESERVED_SPECIMEN" ~ "Specimens", .default = "Observations"
        )
      ) |>
      group_by(Type, Date) |>
      summarise(Records = sum(n_records), .groups = "drop_last") |>
      arrange(Date) |>
      mutate(Records = cumsum(Records))

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#* @get /annotations-plot
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  filter <- list(annotated = TRUE)

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  n <- 500L

  future::future({

    options(op)

    db <- dbConnect(SQLite(), "db-cache.sqlite")

    options(finbif_cache_path = db)

    n_annotations <- fb_occurrence(
      filter = filter,
      select = "record_annotation_created",
      sample = TRUE,
      n = n
    )

    Date <- n_annotations[["record_annotation_created"]]
    Date <- unlist(Date)
    Date <- sort(Date)

    if (is.null(Date)) {

      Date <- Sys.Date()

      Date <- as.character(Date)

      Annotations <- 0

    } else {

      total_annotations <- attr(n_annotations, "nrec_avl")

      Annotations <- length(Date)

      mult <- total_annotations / n

      Annotations <- seq_len(Annotations)

      Annotations <- as.integer(Annotations * mult)

    }

    dbDisconnect(db)

    data.frame(Date = Date, Annotations = Annotations)

  }, seed = TRUE)

}

#* @get /municipality-map
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  filter <- list()

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  future::future({

    options(op)

    db <- dbConnect(SQLite(), "db-cache.sqlite")

    options(finbif_cache_path = db)

    ans <-
      fb_occurrence(
        filter = filter,
        select = c(municipality_name_fi = "municipality"),
        aggregate = "records",
        n = "all", locale = "fi"
      )

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}
