suppressPackageStartupMessages({

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
  library(shiny.i18n, quietly = TRUE)

})

plan(multisession, workers = 2)

options(
  finbif_use_cache = 24,
  finbif_use_cache_metadata = 24,
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

sanitise_lang <- function(lang) {

  switch(lang, fi = "fi", "en")

}

get_children <- function(x, y = character(), cols) {

  is_part_of <- cols$is_part_of

  children <- cols[is_part_of %in% x & !is.na(is_part_of), "id"]

  y <- c(y, children)

  has_children <- cols[children, "has_children"]

  if (!any(has_children, na.rm = TRUE)) {

    y

  } else {

    get_children(children[has_children], y, cols)

  }

}

collection_size <- function(x, cols) {

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

      children <- get_children(x, cols = cols)

      children_size <- cols[children, "collection_size"]

      if (!all(is.na(children_size))) {

        NA_integer_

      } else {

        size

      }

    }

  }

}

has_specimens <- function(x, cols) {

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

      children <- get_children(x, cols = cols)

      children_size <- cols[children, "n_records"]

      if (all(is.na(children_size))) {

        FALSE

      } else {

        TRUE

      }

    }

  }

}

child_is <- function(x, which, cols) {

  children <- get_children(x, cols = cols)

  lgl <- cols[children, which]

  any(lgl)

}

isbotany <- c(
  "fung", "phyt", "botan", "mycota", "lichen", "agaric", "phyll","mycetes",
  "inales", "bacteria", "herbari", "algae", "virus", "vascular plant",
  "kastikka"
)

iszoology <- c(
  "ptera", "animal", "vertebrat", "nymph", "bird", "crustacea", "mammal",
  "mollusc", "fish", "reptil", "zoolog", "oidea", "idae", "insect",
  "arachnid", "squirrel", "chaoboridae", "skeleton", "butterfl", "zmut",
  "aves"
)

isgeology <- c("the geological collections", "fossil ", "fossils ")

text <- c("long_name", "description", "methods", "taxonomic_coverage")

source("collections.R")

translator <- Translator$new(translation_json_path = "translation.json")

if (!dir.exists("logs")) dir.create("logs")

#* @get /healthz
#* @head /healthz
#* @serializer unboxedJSON
function() {

  ""

}

#----species-count----
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

#----collection-count----
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

#----quality-table----
#* @get /quality-table
#* @serializer rds
function(
  collection_quality = "NULL",
  restriction = "NULL",
  taxa = "NULL",
  source = "NULL",
  lang = "en"
) {

  filter <- list(exclude_missing_levels = FALSE)

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  filter[["collection_quality"]] <- sanitise(collection_quality)

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

    levels = c(
      "Expert verified",
      "Community verified",
      "Unassessed",
      "Uncertain",
      "Erroneous"
    )

    ans <-
      fb_occurrence(
        filter = filter,
        select = "record_quality",
        aggregate = "records",
        n = "all"
      ) |>
      mutate(record_quality = replace_na(record_quality, "Unassessed")) |>
      group_by(record_quality) |>
      summarise(n_records = sum(n_records), .groups = "drop") |>
      mutate(
        record_quality = factor(
          record_quality,
          levels = levels,
          labels = translator$t(levels),
          ordered = TRUE
        )
      ) |>
      arrange(record_quality) |>
      adorn_totals(name = translator$t("Total"))

    names(ans) <- translator$t(c("Verification Status", "Number of Records"))

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#----occurrence-plot----
#* @get /occurrence-plot
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL", lang = "en") {

  filter <- list(exclude_missing_levels = FALSE)

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

    ans <-
      fb_occurrence(
        filter = filter,
        select = c(Date = "first_load_date", Type = "superrecord_basis"),
        aggregate = "records",
        n = "all"
      ) |>
      mutate(
        Type = case_match(
          Type,
          "Specimen" ~ translator$t("Specimens"),
          .default = translator$t("Observations")
        ),
        Date = replace_na(Date, min(Date, na.rm = TRUE))
      ) |>
      group_by(Type, Date) |>
      summarise(Records = sum(n_records), .groups = "drop_last") |>
      arrange(Date) |>
      na.omit() |>
      mutate(Records = cumsum(Records))

    if (nrow(ans) < 1L) {

      ans <- data.frame(
        Type = translator$t(c("Observations", "Specimens")),
        Date = as.character(Sys.Date()),
        Records = 0
      )

    }

    dbDisconnect(db)

    names(ans) <- translator$t(names(ans))

    ans

  }, seed = TRUE)

}

#----species-plot----
#* @get /species-plot
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL", lang = "en") {

  filter <- list()

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

    ans <-
      fb_occurrence(
        filter = filter, select = c(Species = "species_scientific_name"),
        aggregate = "records", n = 10L
      ) |>
      arrange(n_records) |>
      mutate(Species = sprintf("<i>%s</i>", Species)) |>
      mutate(Species = factor(Species, levels = Species, ordered = TRUE)) |>
      rename(Records = n_records)

    dbDisconnect(db)

    names(ans) <- translator$t(names(ans))

    ans

  }, seed = TRUE)

}

#----annotations-plot----
#* @get /annotations-plot
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL", lang = "en") {

  filter <- list(annotated = TRUE)

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  filter[["collection"]] <- sanitise(source)

  n <- 500L

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

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

    ans <- data.frame(Date = Date, Annotations = Annotations)

    names(ans) <- translator$t(names(ans))

    ans

  }, seed = TRUE)

}

#----datasets-plot----
#* @get /datasets-plot
#* @serializer rds
function(restriction = "NULL", taxa = "NULL", source = "NULL", lang = "en") {

  filter <- list(subcollections = FALSE)

  filter[["restricted"]] <- sanitise(restriction)

  filter[["informal_groups"]] <- sanitise(taxa)

  collection_source <- sanitise(source)

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

    cols <- fb_collections(
      select = c(id, has_children, is_part_of),
      supercollection = TRUE,
      nmin = NA
    )

    filter[["collection"]] <- NULL

    if (!is.null(collection_source)) {

      filter[["collection"]] <- get_children(collection_source, cols = cols)

    }

    ans <-
      fb_occurrence(
        filter = filter,
        select = c(
          Type = "superrecord_basis",
          Dataset = "collection",
          id = "collection_id"
        ),
        aggregate = "records",
        n = "all",
        locale = lang
      ) |>
      mutate(
        Type = case_match(
          Type,
          "Specimen" ~ translator$t("Specimens"),
          "Näyte" ~ translator$t("Specimens"),
          .default = translator$t("Observations")
        ),
        Dataset = ifelse(
          nchar(Dataset) > 23L,
          paste0(trimws(substr(Dataset, 1L, 24L)), "\u2026"),
          Dataset
        ),
        Dataset = paste0(
          Dataset, " (", sub("http://tun.fi/", "", id), ")"
        ),
        id = NULL
      ) |>
      group_by(Type, Dataset) |>
      summarise(across(n_records, sum), .groups = "keep") |>
      ungroup() |>
      complete(Type, Dataset, fill = list(n_records= 0L)) |>
      group_by(Dataset) |>
      mutate(total_records = sum(n_records)) |>
      arrange(-total_records, Dataset) |>
      select(!total_records)

    if (nrow(ans) > 50L) {

      ans <-
        ans |>
        split(cummax(rep(0:1, each = 48L, length.out = nrow(ans))))

      ans[[2L]] <-
        ans[[2L]] |>
        group_by(Type) |>
        summarise(Dataset = translator$t("Other"), across(n_records, sum))

      ans <- do.call(rbind, ans)

    }

    levels <-
      filter(ans, Type == translator$t("Observations")) |>
      pull(Dataset) |>
      rev()

    ans <-
      mutate(ans, Dataset = factor(Dataset, levels = levels)) |>
      rename(Records = n_records)

    dbDisconnect(db)

    names(ans) <- translator$t(names(ans))

    ans

  }, seed = TRUE)

}

#----municipality-map----
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
        select = c(municipality_name_fi = "finnish_municipality"),
        aggregate = "records",
        n = "all",
        locale = "fi"
      )

    dbDisconnect(db)

    ans

  }, seed = TRUE)

}

#----bio-province-map----
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

#----specimen-collections----
#* @get /specimen-collections
#* @serializer rds
function(
  stat = "n_collections",
  institution = "NULL",
  discipline = "NULL",
  lang = "en"
) {

  institution <- sanitise(institution)

  discipline <- sanitise(discipline)

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

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
      nmin = NA,
      local = lang
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

    cols$n_specimens <- vapply(cols$id, collection_size, 0, cols = cols)

    specimen_count <- fb_occurrence(
      filter = list(superrecord_basis = "specimen", subcollections = FALSE),
      select = c(id = "collection_id"),
      aggregate = "records",
      n = "all"
    )

    specimen_count[["id"]] <- sub("http://tun.fi/", "", specimen_count[["id"]])

    cols <- merge(cols, specimen_count, all.x = TRUE)

    rownames(cols) <- cols$id

    cols <- subset(cols, vapply(cols$id, has_specimens, NA, cols = cols))

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

    cols$botany <- grepl(paste(isbotany, collapse = "|"), text)

    cols$zoology <- grepl(paste(iszoology, collapse = "|"), text)

    cols$geology <- grepl(paste(isgeology, collapse = "|"), text)

    cols$botany <- cols$botany & !cols$zoology & !cols$geology

    cols$zoology <- cols$zoology & !cols$botany & !cols$geology

    cols <- transform(
      cols, botany = botany | vapply(id, child_is, NA, "botany", cols = cols)
    )

    cols <- transform(
      cols, zoology = zoology | vapply(id, child_is, NA, "zoology", cols = cols)
    )

    cols <- transform(
      cols, geology = geology | vapply(id, child_is, NA, "geology", cols = cols)
    )

    cols <- transform(cols, NULL = TRUE)

    if (!is.null(discipline)) {

      cols <- filter(cols, .data[[discipline]])

    }

    if (!is.null(institution)) {

      children <- get_children(institution, cols = cols)

      cols <- filter(cols, id %in% c(institution, children))

    }

    cols <- filter(cols, n_specimens > 0L)

    n_collections <- nrow(cols)

    n_specimens <- pull(cols, n_specimens)

    n_specimens <- sum(n_specimens)

    n_specimens_digitised <- pull(cols, n_specimens_digitised)

    n_specimens_digitised <- sum(n_specimens_digitised)

    n_specimens_imaged <- pull(cols, n_specimens_imaged)

    n_specimens_imaged <- sum(n_specimens_imaged)

    tbl_data <- data.frame(
      Collection = character(), Status = character(), n = integer()
    )

    if (nrow(cols) > 0L) {

      tbl_data <-
        cols |>
        mutate(
          Collection = ifelse(
            nchar(long_name) > 37L,
            paste0(trimws(substr(long_name, 1L, 38L)), "\u2026"),
            long_name
          ),
          Collection = paste0(Collection, " (", id, ")")
        ) |>
        arrange(-n_specimens_digitised) |>
        mutate(Undigitised = n_specimens - n_specimens_digitised) |>
        mutate(`Digitised Only` = n_specimens_digitised - n_specimens_imaged) |>
        mutate(Imaged = n_specimens_imaged) |>
        select(Collection, Undigitised, `Digitised Only`, Imaged) |>
        split(cummax(rep(0:1, each = 24L, length.out = nrow(cols))))

      if (length(tbl_data) > 1L) {

        tbl_data[[2L]] <- summarise(
          tbl_data[[2L]],
          Collection = translator$t("Other"),
          across(!Collection, sum),
          .groups = "drop_last"
        )

      }

      statuses <- c("Imaged", "Digitised Only", "Undigitised")

      tbl_data <-
        do.call(rbind, tbl_data) |>
        mutate(Collection = factor(Collection, levels = rev(Collection))) |>
        pivot_longer(!Collection, names_to = "Status", values_to = "n") |>
        mutate(
          Status = factor(
            Status, levels = statuses, labels = translator$t(statuses)
          )
        )

      names(tbl_data) <- translator$t(c("Collection", "Status", "Specimens"))

    }

    dbDisconnect(db)

    switch(
      stat,
      n_collections = n_collections,
      n_specimens = n_specimens,
      n_specimens_digitised = n_specimens_digitised,
      n_specimens_imaged = n_specimens_imaged,
      percent_digitised = round(n_specimens_digitised / n_specimens * 100),
      percent_imaged = round(n_specimens_imaged / n_specimens * 100),
      table = tbl_data
    )

  }, seed = TRUE)

}

#----progress-plot----
#* @get /progress-plot
#* @serializer rds
function(institution = "NULL", discipline = "NULL", lang = "en") {

  institution <- sanitise(institution)

  discipline <- sanitise(discipline)

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

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

    cols <- subset(cols, vapply(cols$id, has_specimens, NA, cols = cols))

    text <- tolower(do.call(paste, cols[, text]))

    cols$botany <- grepl(paste(isbotany, collapse = "|"), text)

    cols$zoology <- grepl(paste(iszoology, collapse = "|"), text)

    cols$geology <- grepl(paste(isgeology, collapse = "|"), text)

    cols$botany <- cols$botany & !cols$zoology & !cols$geology

    cols$zoology <- cols$zoology & !cols$botany & !cols$geology

    cols <- transform(
      cols, botany = botany | vapply(id, child_is, NA, "botany", cols = cols)
    )

    cols <- transform(
      cols, zoology = zoology | vapply(id, child_is, NA, "zoology", cols = cols)
    )

    cols <- transform(
      cols, geology = geology | vapply(id, child_is, NA, "geology", cols = cols)
    )

    cols <- transform(cols, NULL = TRUE)

    collections <- NULL

    if (!is.null(discipline)) {

      cols <- filter(cols, .data[[discipline]])

      collections <- cols$id

    }

    if (!is.null(institution)) {

      children <- get_children(institution, cols = cols)

      cols <- filter(cols, id %in% c(institution, children))

      collections <- cols$id

    }

    if (is.null(collections) || length(collections) > 0L) {

      options(finbif_max_page_size = 1000L)

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
            translator$t("Imaged"),
            translator$t("Unimaged")
          ),
          Date
        ) |>
        summarise(n_records = sum(n_records), .groups = "drop_last") |>
        group_by(Status, Date) |>
        summarise(Specimens = sum(n_records), .groups = "drop_last") |>
        arrange(Date) |>
        mutate(Specimens = cumsum(Specimens)) |>
        select(Status, Specimens, Date)

      options(finbif_max_page_size = op[["finbif_max_page_size"]])

    } else {

      Date <- Sys.Date()

      Date <- as.character(Date)

      Specimens <- c(0, 0)

      Status <- c("Imaged", "Unimaged")

      ans <- data.frame(Status = Status, Specimens = Specimens, Date = Date)

    }

    dbDisconnect(db)

    names(ans) <- translator$t(names(ans))

    ans

  }, seed = TRUE)

}

#----specimen-map----
#* @get /specimen-map
#* @serializer rds
function(mapinstitution= "NULL", mapdiscipline = "NULL", lang = "en") {

  mapinstitution <- sanitise(mapinstitution)

  mapdiscipline <- sanitise(mapdiscipline)

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

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

    cols <- subset(cols, vapply(cols$id, has_specimens, NA, cols = cols))

    text <- tolower(do.call(paste, cols[, text]))

    cols$botany <- grepl(paste(isbotany, collapse = "|"), text)

    cols$zoology <- grepl(paste(iszoology, collapse = "|"), text)

    cols$geology <- grepl(paste(isgeology, collapse = "|"), text)

    cols$botany <- cols$botany & !cols$zoology & !cols$geology

    cols$zoology <- cols$zoology & !cols$botany & !cols$geology

    cols <- transform(
      cols, botany = botany | vapply(id, child_is, NA, "botany", cols = cols)
    )

    cols <- transform(
      cols, zoology = zoology | vapply(id, child_is, NA, "zoology", cols = cols)
    )

    cols <- transform(
      cols, geology = geology | vapply(id, child_is, NA, "geology", cols = cols)
    )

    cols <- transform(cols, NULL = TRUE)

    collections <- NULL

    if (!is.null(mapinstitution)) {

      children <- get_children(mapinstitution, cols = cols)

      cols <- filter(cols, id %in% c(mapinstitution, children))

      collections <- cols$id

    }

    if (!is.null(mapdiscipline)) {

      cols <- filter(cols, .data[[mapdiscipline]])

      collections <- cols$id

    }

    countries <- finbif_metadata("country", locale = lang)

    countries <- countries[!is.na(countries[["code"]]), ]

    if (is.null(collections) || length(collections) > 0L) {

      records <- fb_occurrence(
        filter = list(
          collection = collections, superrecord_basis = "specimen",
          subcollections = FALSE
        ),
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

      rownames(countries) <- countries[["code"]]

      ans <-
        map("world", plot = FALSE, fill = TRUE) |>
        st_as_sf() |>
        mutate(code = ifelse(ID == "Namibia", "NA", iso.alpha(ID))) |>
        left_join(records, by = join_by(code)) |>
        mutate(ID = countries[code, "name"]) |>
        mutate(Specimens = replace_na(Specimens, 0L)) |>
        mutate(text = paste0(ID, ": " , Specimens))

    } else {

      rownames(countries) <- countries[["code"]]

      ans <-
        map("world", plot = FALSE, fill = TRUE) |>
        st_as_sf() |>
        mutate(
          code = ifelse(ID == "Namibia", "NA", iso.alpha(ID)), Specimens = 0L
        ) |>
        mutate(ID = countries[code, "name"]) |>
        mutate(text = paste0(ID, ": " , Specimens))

    }

    dbDisconnect(db)

    names(ans)[which(names(ans) == "Specimens")] <- translator$t("Specimens")

    ans

  }, seed = TRUE)

}

#----cit-sci-species-count----
#* @get /cit-sci-species-count
#* @serializer rds
function(projects = "NULL", lang = "en") {

  filter <- list(subcollections = FALSE, exclude_missing_levels = FALSE)

  filter[["collection"]] <- sanitise(projects)

  if (is.null(filter[["collection"]])) {

    filter[["collection"]] <- unname(collections$cit_sci_projects)

  }

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

    ans <-
      fb_occurrence(
        filter = filter, select = c(Year = "year"), aggregate = "species",
        n = "all"
      ) |>
      rename(Species = n_species)

    dbDisconnect(db)

    names(ans) <- translator$t(names(ans))

    ans

  }, seed = TRUE)

}

#----cit-sci-user-count----
#* @get /cit-sci-user-count
#* @serializer rds
function(projects = "NULL", lang = "en") {

  filter <- list(subcollections = FALSE, exclude_missing_levels = FALSE)

  filter[["collection"]] <- sanitise(projects)

  if (is.null(filter[["collection"]])) {

    filter[["collection"]] <- unname(collections$cit_sci_projects)

  }

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

    n_user_years <- fb_occurrence(
      filter = filter, select = c("team_member", Year = "year"),
      aggregate = "records", count_only = TRUE
    )

    record_years <- fb_occurrence(
      filter = filter, select = c(Year = "year"), aggregate = "records",
      n = "all"
    )

    ans <-
      fb_occurrence(
        filter = filter, select = c("team", Year = "year"), sample = TRUE,
        n = 3000L
      ) |>
      unnest(team) |>
      count(Year) |>
      right_join(record_years, by = join_by(Year)) |>
      mutate(
        n_star = n_records * mean(n / n_records, na.rm = TRUE),
        Users = round(1 + n_star * ((n_user_years - n()) / sum(n_star)))
      ) |>
      select(Year, Users)

    dbDisconnect(db)

    names(ans) <- translator$t(names(ans))

    ans

  }, seed = TRUE)

}

#----occurrence-citsci----
#* @get /occurrence-citsci
#* @serializer rds
function(projects = "NULL", lang = "en") {

  filter <- list(subcollections = FALSE, exclude_missing_levels = FALSE)

  filter[["collection"]] <- sanitise(projects)

  if (is.null(filter[["collection"]])) {

    filter[["collection"]] <- unname(collections$cit_sci_projects)

  }

  lang <- sanitise_lang(lang)

  future_promise({

    options(op)

    db <- dbConnect(Postgres(), dbname = Sys.getenv("DB_NAME"))

    options(finbif_cache_path = db)

    translator$set_translation_language(lang)

    ans <-
      fb_occurrence(
        filter = filter,
        select = c(Project = "collection_id"),
        aggregate = "records",
        n = "all"
      ) |>
      mutate(
        Project = translator$t(
          names(
            collections$cit_sci_projects[
              match(
                sub("http://tun.fi/", "", Project),
                collections$cit_sci_projects
              )
            ]
          )
        )
      ) |>
      arrange(-n_records) |>
      rename(Occurrences = n_records) |>
      mutate(Project = factor(Project, levels = rev(Project)))

    dbDisconnect(db)

    names(ans) <- translator$t(names(ans))

    ans

  }, seed = TRUE)

}
