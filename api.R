library(DBI, quietly = TRUE)
library(dplyr, quietly = TRUE)
library(finbif, quietly = TRUE)
library(future, quietly = TRUE)
library(janitor, quietly = TRUE)
library(maps, quietly = TRUE)
library(promises, quietly = TRUE)
library(RPostgres, quietly = TRUE)
library(sf, quietly = TRUE)
library(tidyr, quietly = TRUE)

plan(multisession)

options(
  finbif_use_cache = 24,
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

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

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

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

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

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

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

  filter <- list(exclude_missing_levels = FALSE)

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  filter[["collection_quality"]] <- sanitise(collection_quality)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    ans <-
      fb_occurrence(
        filter = filter,
        select = c(`Verification Status` = "record_quality"),
        aggregate = "records",
        n = "all"
      ) |>
      mutate(
        `Verification Status` = replace_na(`Verification Status`, "Unassessed")
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

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

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
          Type, "Specimen" ~ "Specimens", .default = "Observations"
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

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

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

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

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

#* @get /bio-province-map
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL") {

  filter <- list()

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    ans <-
      fb_occurrence(
        filter = filter,
        select = c(MAAKUNTA_FI = "bio_province"),
        aggregate = "records",
        n = "all", locale = "fi"
      )

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#* @get /specimen-collections
#* @serializer rds
function(stat = "n_specimens", spec_source = "NULL", discipline = "NULL") {

  spec_source <- sanitise(spec_source)

  discipline <- sanitise(discipline)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    get_children <- function(x, y = character()) {

      is_part_of <- cols$is_part_of

      children <- cols[is_part_of %in% x & !is.na(is_part_of), "id"]

      y <- c(y, children)

      has_children <- cols[children, "has_children"]

      if (!any(has_children, na.rm = TRUE)) {

        y

      } else {

        get_children(children[has_children], y)

      }

    }

    collection_size <- function(x) {

      row <- cols[x, ]

      size <- row[["collection_size"]]

      if (is.na(size)) {

        size

      } else {

        has_children <- row[["has_children"]]

        if (!has_children) {

          size

        } else {

          is_part_of <- cols[["is_part_of"]]

          children <- get_children(x)

          children_size <- cols[children, "collection_size"]

          if (!all(is.na(children_size))) {

            NA_integer_

          } else {

            size

          }

        }

      }

    }

    has_specimens <- function(x) {

      row <- cols[x, ]

      size <- row[["n_records"]]

      if (!is.na(size)) {

        TRUE

      } else {

        has_children <- isTRUE(row[["has_children"]])

        if (!has_children) {

          FALSE

        } else {

          is_part_of <- cols[["is_part_of"]]

          children <- get_children(x)

          children_size <- cols[children, "n_records"]

          if (all(is.na(children_size))) {

            FALSE

          } else {

            TRUE

          }

        }

      }

    }

    child_is <- function(x, which) {

      children <- get_children(x)

      lgl <- cols[children, which]

      any(lgl)

    }

    botany <- c(
      "fung", "phyt", "botan", "mycota", "lichen", "agaric", "phyll","mycetes",
      "inales", "bacteria", "herbari", "algae", "virus", "vascular plant",
      "kastikka"
    )

    zoology <- c(
      "ptera", "animal", "vertebrat", "nymph", "bird", "crustacea", "mammal",
      "mollusc", "fish", "reptil", "zoolog", "oidea", "idae", "insect",
      "arachnid", "squirrel", "chaoboridae", "skeleton", "butterfl", "zmut",
      "aves"
    )

    geology <- c("the geological collections", "fossil ", "fossils ")

    text <- c("long_name", "description", "methods", "taxonomic_coverage")

    cols <- fb_collections(
      select = c(
        id,
        long_name,
        has_children,
        description,
        is_part_of,
        methods,
        notes,
        taxonomic_coverage,
        types_size,
        owner,
        collection_size,
        digitized_size,
        count
      ),
      supercollection = TRUE,
      nmin = NA
    )

    cols <- transform(cols, digitized_size = as.integer(digitized_size))

    cols <- transform(
      cols,
      collection_size = ifelse(
        is.na(collection_size),
        round(count / digitized_size * 100),
        as.integer(collection_size)
      )
    )

    cols$n_specimens <- vapply(cols$id, collection_size, 0)

    specimen_count <- fb_occurrence(
      filter = list(superrecord_basis = "specimen", subcollections = FALSE),
      select = c(id = "collection_id"),
      aggregate = "records",
      n = "all"
    )

    specimen_count[["id"]] <- sub("http://tun.fi/", "", specimen_count[["id"]])

    cols <- merge(cols, specimen_count, all.x = TRUE)

    rownames(cols) <- cols$id

    cols <- subset(cols, vapply(cols$id, has_specimens, NA))

    cols <- transform(
      cols,
      n_specimens_digitised = ifelse(is.na(n_records), 0L, n_records),
      n_records = NULL
    )

    imaged_count <- fb_occurrence(
      filter = list(
        has_record_images = TRUE, superrecord_basis = "specimen",
        subcollections = FALSE
      ),
      select = c(id = "collection_id"),
      aggregate = "records",
      n = "all"
    )

    imaged_count[["id"]] <- sub("http://tun.fi/", "", imaged_count[["id"]])

    cols <- merge(cols, imaged_count, all.x = TRUE)

    cols <- transform(
      cols,
      n_specimens_imaged = ifelse(is.na(n_records), 0L, n_records),
      n_records = NULL
    )

    rownames(cols) <- cols$id

    cols <- transform(cols, prop_spec = n_specimens_digitised / count)

    cols <- transform(cols, prop_spec = ifelse(is.nan(prop_spec), 1, prop_spec))

    cols <- transform(
      cols, n_specimens = ifelse(prop_spec < .5, NA, n_specimens)
    )

    cols <- transform(
      cols,
      n_specimens = ifelse(
        is.na(n_specimens),
        round(n_specimens_digitised / digitized_size * 100),
        n_specimens
      )
    )

    cols <- transform(
      cols,
      n_specimens = ifelse(
        is.na(n_specimens) | is.nan(n_specimens),
        n_specimens_digitised,
        pmax(n_specimens, n_specimens_digitised)
      )
    )

    text <- tolower(do.call(paste, cols[, text]))

    cols$is_botany <- grepl(paste(botany, collapse = "|"), text)

    cols$is_zoology <- grepl(paste(zoology, collapse = "|"), text)

    cols$is_geology <- grepl(paste(geology, collapse = "|"), text)

    cols$is_botany <- cols$is_botany & !cols$is_zoology & !cols$is_geology

    cols$is_zoology <- cols$is_zoology & !cols$is_botany & !cols$is_geology

    cols <- transform(
      cols, is_botany = is_botany | vapply(id, child_is, NA, "is_botany")
    )

    cols <- transform(
      cols, is_zoology = is_zoology | vapply(id, child_is, NA, "is_zoology")
    )

    cols <- transform(
      cols, is_geology = is_geology | vapply(id, child_is, NA, "is_geology")
    )

    cols <- transform(cols, NULL = TRUE)

    if (!is.null(discipline)) {

      cols <- filter(cols, .data[[discipline]])

    }

    if (!is.null(spec_source)) {

      children <- get_children(spec_source)

      cols <- filter(cols, id %in% children)

    }

    n_specimens <- pull(cols, n_specimens)

    n_specimens <- sum(n_specimens)

    n_specimens_digitised <- pull(cols, n_specimens_digitised)

    n_specimens_digitised <- sum(n_specimens_digitised)

    n_specimens_imaged <- pull(cols, n_specimens_imaged)

    n_specimens_imaged <- sum(n_specimens_imaged)

    tbl_data <- data.frame(
      Collection = character(), Status = character(), n = integer()
    )

    cols <- filter(cols, n_specimens > 0L)

    if (nrow(cols) > 0L) {

      tbl_data <-
        cols |>
        mutate(
          Collection = ifelse(
            nchar(long_name) > 44L,
            paste0(trimws(substr(long_name, 1L, 45L)), "\u2026"),
            long_name
          )
        ) |>
        arrange(-n_specimens_digitised) |>
        mutate(Undigitised = n_specimens - n_specimens_digitised) |>
        mutate(`Digitised Only` = n_specimens_digitised - n_specimens_imaged) |>
        mutate(Imaged = n_specimens_imaged) |>
        select(Collection, Undigitised, `Digitised Only`, Imaged) |>
        split(cummax(rep(0:1, each = 24L, length.out = nrow(cols))))

      if (length(tbl_data) > 1L) {

        tbl_data[[2L]] <- summarise(
          tbl_data[[2L]], Collection = "Other", across(!Collection, sum)
        )

      }

      tbl_data <-
        do.call(rbind, tbl_data) |>
        mutate(Collection = factor(Collection, levels = rev(Collection))) |>
        pivot_longer(!Collection, names_to = "Status", values_to = "n") |>
        mutate(
          Status = factor(
            Status, levels = c("Imaged", "Digitised Only", "Undigitised")
          )
        )

    }

    dbDisconnect(db)

    switch(
      stat,
      n_specimens = n_specimens,
      n_specimens_digitised = n_specimens_digitised,
      n_specimens_imaged = n_specimens_imaged,
      percent_digitised = round(n_specimens_digitised / n_specimens * 100),
      percent_imaged = round(n_specimens_imaged / n_specimens * 100),
      table = tbl_data
    )

  }, seed = TRUE)

}

#* @get /progress-plot
#* @serializer rds
function(spec_source = "NULL", discipline = "NULL") {

  spec_source <- sanitise(spec_source)

  discipline <- sanitise(discipline)

  future_promise({

    botany <- c(
      "fung", "phyt", "botan", "mycota", "lichen", "agaric", "phyll","mycetes",
      "inales", "bacteria", "herbari", "algae", "virus", "vascular plant",
      "kastikka"
    )

    zoology <- c(
      "ptera", "animal", "vertebrat", "nymph", "bird", "crustacea", "mammal",
      "mollusc", "fish", "reptil", "zoolog", "oidea", "idae", "insect",
      "arachnid", "squirrel", "chaoboridae", "skeleton", "butterfl", "zmut",
      "aves"
    )

    geology <- c("the geological collections", "fossil ", "fossils ")

    text <- c("long_name", "description", "methods", "taxonomic_coverage")

    get_children <- function(x, y = character()) {

      is_part_of <- cols$is_part_of

      children <- cols[is_part_of %in% x & !is.na(is_part_of), "id"]

      y <- c(y, children)

      has_children <- cols[children, "has_children"]

      if (!any(has_children, na.rm = TRUE)) {

        y

      } else {

        get_children(children[has_children], y)

      }

    }

    has_specimens <- function(x) {

      row <- cols[x, ]

      size <- row[["n_records"]]

      if (!is.na(size)) {

        TRUE

      } else {

        has_children <- isTRUE(row[["has_children"]])

        if (!has_children) {

          FALSE

        } else {

          is_part_of <- cols[["is_part_of"]]

          children <- get_children(x)

          children_size <- cols[children, "n_records"]

          if (all(is.na(children_size))) {

            FALSE

          } else {

            TRUE

          }

        }

      }

    }

    child_is <- function(x, which) {

      children <- get_children(x)

      lgl <- cols[children, which]

      any(lgl)

    }

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    cols <- fb_collections(
      select = c(
        id,
        long_name,
        description,
        methods,
        taxonomic_coverage,
        has_children,
        is_part_of
      ),
      supercollection = TRUE,
      nmin = NA
    )

    specimen_count <- fb_occurrence(
      filter = list(superrecord_basis = "specimen", subcollections = FALSE),
      select = c(id = "collection_id"),
      aggregate = "records",
      n = "all"
    )

    specimen_count[["id"]] <- sub("http://tun.fi/", "", specimen_count[["id"]])

    cols <- merge(cols, specimen_count, all.x = TRUE)

    rownames(cols) <- cols$id

    cols <- subset(cols, vapply(cols$id, has_specimens, NA))

    text <- tolower(do.call(paste, cols[, text]))

    cols$is_botany <- grepl(paste(botany, collapse = "|"), text)

    cols$is_zoology <- grepl(paste(zoology, collapse = "|"), text)

    cols$is_geology <- grepl(paste(geology, collapse = "|"), text)

    cols$is_botany <- cols$is_botany & !cols$is_zoology & !cols$is_geology

    cols$is_zoology <- cols$is_zoology & !cols$is_botany & !cols$is_geology

    cols <- transform(
      cols, is_botany = is_botany | vapply(id, child_is, NA, "is_botany")
    )

    cols <- transform(
      cols, is_zoology = is_zoology | vapply(id, child_is, NA, "is_zoology")
    )

    cols <- transform(
      cols, is_geology = is_geology | vapply(id, child_is, NA, "is_geology")
    )

    cols <- transform(cols, NULL = TRUE)

    collections <- NULL

    if (!is.null(discipline)) {

      cols <- filter(cols, .data[[discipline]])

      collections <- cols$id

    }

    if (!is.null(spec_source)) {

      children <- get_children(spec_source)

      cols <- filter(cols, id %in% children)

      collections <- cols$id

    }

    if (is.null(collections) || length(collections) > 0L) {

      ans <-
        fb_occurrence(
          filter = list(
            collection = collections, superrecord_basis = "specimen",
            subcollections = FALSE
          ),
          select = c(Date = "first_load_date", "record_image_count"),
          aggregate = "records",
          n = "all"
        ) |>
        group_by(
          Status = ifelse(
            record_image_count > 0L | is.na(record_image_count),
            "Imaged",
            "Unimaged"
          ),
          Date
        ) |>
        summarise(n_records = sum(n_records)) |>
        group_by(Status, Date) |>
        summarise(Specimens = sum(n_records), .groups = "drop_last") |>
        arrange(Date) |>
        mutate(Specimens = cumsum(Specimens))

    } else {

      Date <- Sys.Date()

      Date <- as.character(Date)

      Specimens <- c(0, 0)

      Status <- c("Imaged", "Unimaged")

      ans <- data.frame(Status = Status, Specimens = Specimens, Date = Date)

    }

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#* @get /specimen-map
#* @serializer rds
function() {

  filter = list(superrecord_basis = "specimen")

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    countries <- finbif_metadata("country")

    records <- fb_occurrence(
      filter = c(superrecord_basis = "specimen"),
      select = "country_id", aggregate = "records", n = "all"
    )

    records <- transform(
      records,
      code = countries[sub("http://tun.fi/", "", country_id), "code"],
      Specimens = n_records,
      country_id = NULL,
      n_records = NULL
    )

    records <- na.omit(records)

    ans <-
      map("world", plot = FALSE, fill = TRUE) |>
      st_as_sf() |>
      mutate(code = ifelse(ID == "Namibia", "NA", iso.alpha(ID))) |>
      left_join(records) |>
      mutate(text = paste0(ID, ": " , Specimens))

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}
