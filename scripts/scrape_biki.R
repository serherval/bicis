# scripts/scrape_biki.R
#
# Descarga el estado actual de BIKI directamente del feed GBFS oficial
# (publicado por el operador PBSC/Lyft Urban Solutions via datos abiertos
# de AUVASA) y añade una fila por estación al histórico acumulado.
#
# No requiere ningún servidor intermedio: son 3 peticiones HTTP directas
# a valladolid.publicbikesystem.net.

library(httr)
library(jsonlite)
library(dplyr)
library(tidyr)
library(readr)
library(sf)

BASE_URL <- "https://valladolid.publicbikesystem.net/customer/gbfs/v2/es"

BARRIOS_PATH <- "data/barrios_valladolid.geojson"
COL_BARRIO   <- "NOMBRE"  # EDITA si tu geojson usa otro nombre de columna

get_gbfs <- function(feed_name) {
  resp <- tryCatch(
    GET(paste0(BASE_URL, "/", feed_name), timeout(15)),
    error = function(e) {
      message("No se pudo contactar el feed '", feed_name, "': ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(resp) || status_code(resp) != 200) {
    message("Feed '", feed_name, "' no disponible (status: ",
            if (is.null(resp)) "sin respuesta" else status_code(resp), ")")
    quit(save = "no", status = 0)  # no marcar el Action en rojo por un fallo puntual
  }
  fromJSON(content(resp, "text", encoding = "UTF-8"), simplifyDataFrame = TRUE)
}

# 1. Información fija de las estaciones (nombre, lat, lon, capacidad)
info_raw <- get_gbfs("station_information")
estaciones <- info_raw$data$stations %>%
  as_tibble() %>%
  select(station_id, nombre = name, lat, lon, any_of("capacity"))

# 2. Diccionario de tipos de vehículo -> mecánica / eléctrica
tipos_raw <- get_gbfs("vehicle_types")
tipos <- tipos_raw$data$vehicle_types %>%
  as_tibble() %>%
  select(vehicle_type_id, propulsion_type) %>%
  mutate(tipo = case_when(
    propulsion_type == "human"    ~ "mecanicas",
    propulsion_type == "electric" ~ "electricas",
    TRUE ~ "otras"
  ))

# 3. Estado en tiempo real (bicis disponibles por tipo, docks libres)
status_raw <- get_gbfs("station_status")
status <- status_raw$data$stations %>%
  as_tibble() %>%
  select(station_id, num_docks_available, vehicle_types_available) %>%
  unnest(vehicle_types_available) %>%
  left_join(tipos, by = "vehicle_type_id") %>%
  group_by(station_id, num_docks_available, tipo) %>%
  summarise(n = sum(count), .groups = "drop") %>%
  pivot_wider(names_from = tipo, values_from = n, values_fill = 0) %>%
  rename(libres = num_docks_available)

# Asegurar que existen ambas columnas aunque algún snapshot no traiga eléctricas
if (!"mecanicas" %in% names(status)) status$mecanicas <- 0
if (!"electricas" %in% names(status)) status$electricas <- 0

snapshot <- estaciones %>%
  inner_join(status, by = "station_id") %>%
  transmute(
    puesto     = station_id,
    nombre,
    lat, lon,
    libres,
    mecanicas,
    electricas,
    timestamp  = format(Sys.time(), tz = "Europe/Madrid", usetz = TRUE)
  )

# 4. Asignar barrio por posición (join espacial), si el geojson está disponible
if (file.exists(BARRIOS_PATH)) {
  barrios <- st_read(BARRIOS_PATH, quiet = TRUE)
  puestos_sf <- snapshot %>%
    distinct(puesto, lat, lon) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  puestos_barrio <- st_join(puestos_sf, barrios) %>%
    st_drop_geometry() %>%
    transmute(puesto, barrio = .data[[COL_BARRIO]])
  snapshot <- snapshot %>% left_join(puestos_barrio, by = "puesto")
} else {
  warning("No se encontró ", BARRIOS_PATH, " — el snapshot se guarda sin columna 'barrio'.")
  snapshot <- snapshot %>% mutate(barrio = NA_character_)
}

hist_path <- "data/biki_history.csv"
dir.create(dirname(hist_path), showWarnings = FALSE, recursive = TRUE)

if (file.exists(hist_path)) {
  write_csv(snapshot, hist_path, append = TRUE)
} else {
  write_csv(snapshot, hist_path)
}

message("Snapshot guardado: ", nrow(snapshot), " estaciones, ", Sys.time())
