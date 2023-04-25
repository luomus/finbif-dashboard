library(DBI, quietly = TRUE)
library(dplyr, quietly = TRUE)
library(finbif, quietly = TRUE)
library(ggplot2, quietly = TRUE)
library(janitor, quietly = TRUE)
library(lubridate, quietly = TRUE)
library(RSQLite, quietly = TRUE)
library(scales, quietly = TRUE)
library(tidyr, quietly = TRUE)

db <- dbConnect(SQLite(), "db-cache.sqlite")

options(
  finbif_use_cache = 0.05,
  finbif_cache_offset = .5,
  finbif_cache_path = db,
  finbif_hide_progress = TRUE,
  finbif_rate_limit = Inf,
  finbif_max_page_size = 3000L,
  finbif_use_async = FALSE
)

base_filter <- list(
  quality_issues = "both",
  record_reliability = c(
    "reliable",
    "unassessed",
    "unreliable"
  ),
  record_quality = c(
    "expert_verified",
    "community_verified",
    "unassessed",
    "uncertain",
    "erroneous"
  )
)

sanitise <- function(x) {

  switch(x, `NULL` = NULL, x)

}

#* @get /record-count
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  restriction <- sanitise(restriction)

  taxa <- sanitise(taxa)

  source <- sanitise(source)

  record_count_filter <- c(
    base_filter,
    list(restricted = restriction, informal_groups = taxa, collection = source)
  )

  fb_occurrence(
    filter = record_count_filter,
    select = "record_id",
    count_only = TRUE
  )

}

#* @get /species-count
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  restriction <- sanitise(restriction)

  taxa <- sanitise(taxa)

  source <- sanitise(source)

  species_count_filter <- c(
    base_filter,
    list(restricted = restriction, informal_groups = taxa, collection = source)
  )

  fb_occurrence(
    filter = species_count_filter,
    select = "species_scientific_name",
    aggregate = "records",
    count_only = TRUE
  )

}

#* @get /collection-count
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  restriction <- sanitise(restriction)

  taxa <- sanitise(taxa)

  source <- sanitise(source)

  collection_count_filter <- c(
    base_filter,
    list(restricted = restriction, informal_groups = taxa, collection = source)
  )

  fb_occurrence(
    filter = collection_count_filter,
    select = "collection_id",
    aggregate = "records",
    count_only = TRUE
  )

}

#* @get /quality-table
#* @serializer rds
function(collection_quality = "NULL", restriction = "NULL", taxa = "NULL", source = "NULL") {

  collection_quality <- sanitise(collection_quality)

  restriction <- sanitise(restriction)

  taxa <- sanitise(taxa)

  source <- sanitise(source)

  quality_table_filter <- c(
    base_filter,
    list(
      collection_quality = collection_quality,
      restricted = restriction,
      informal_groups = taxa,
      collection = source
    )
  )

  fb_occurrence(
    filter = quality_table_filter,
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

}

#* @get /occurrence-plot
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  restriction <- sanitise(restriction)

  taxa <- sanitise(taxa)

  source <- sanitise(source)

  occurrence_filter <- c(
    base_filter,
    list(
      restricted = restriction, informal_groups = taxa, collection = source
    )
  )

  fb_occurrence(
    filter = occurrence_filter,
    select = "first_load_date",
    aggregate = "records",
    n = "all"
  ) |>
  arrange(first_load_date) |>
  mutate(
    Date = as.Date(first_load_date), Records = cumsum(n_records)
  ) |>
  ggplot() +
  aes(x = Date, y = Records) +
  geom_line() +
  scale_y_continuous(label = comma) +
  labs(x = NULL, y = "Records")

}

#* @get /annotations-plot
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  restriction <- sanitise(restriction)

  taxa <- sanitise(taxa)

  source <- sanitise(source)

  annotations_filter <- c(
    base_filter,
    list(
      annotated = TRUE,
      restricted = restriction,
      informal_groups = taxa,
      collection = source
    )
  )

  n <- 500

  n_annotations <- fb_occurrence(
    filter = annotations_filter,
    select = "record_annotation_created",
    sample = TRUE,
    n = n
  )

  Date <- n_annotations[["record_annotation_created"]]
  Date <- unlist(Date)
  Date <- sort(Date)

  if (is.null(Date)) {

    Date <- Sys.Date()

    Annotations <- 0

  } else {

    Date <- as_date(Date)

    total_annotations <- attr(n_annotations, "nrec_avl")

    Annotations <- length(Date)

    mult <- total_annotations / n

    Annotations <- seq_len(Annotations)

    Annotations <- as.integer(Annotations * mult)

  }

  ggplot() +
  aes(x = Date, y = Annotations) +
  geom_line() +
  scale_y_continuous(label = comma) +
  labs(x = NULL, y = "Annotations")

}
