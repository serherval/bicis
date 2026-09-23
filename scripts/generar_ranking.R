# scripts/generar_ranking.R
#
# Genera data/ranking_diario.png con el top 10 de estaciones con más bicis
# a partir del último snapshot del histórico. Pensado para publicar a mano
# (o via API de X) tras cada ejecución del workflow.

library(dplyr)
library(readr)
library(ggplot2)

hist_data <- read_csv(
  "data/biki_history.csv",
  show_col_types = FALSE,
  col_types = cols(timestamp = col_datetime())
)

if (any(is.na(hist_data$timestamp))) {
  warning("Algunas filas de 'timestamp' no se han podido parsear como fecha/hora; revisa el formato en data/biki_history.csv")
}

ultimo <- hist_data %>% filter(timestamp == max(timestamp))

top10 <- ultimo %>%
  mutate(total_bicis = mecanicas + electricas) %>%
  arrange(desc(total_bicis)) %>%
  slice_head(n = 10)

p <- ggplot(top10, aes(x = reorder(nombre, total_bicis), y = total_bicis)) +
  geom_col(fill = "#f97316") +
  coord_flip() +
  labs(
    title = "BIKI Valladolid — Top 10 estaciones con más bicis",
    subtitle = paste("Actualizado:", format(max(hist_data$timestamp), "%d/%m %H:%M")),
    x = NULL, y = "Bicis disponibles"
  ) +
  theme_minimal(base_size = 14)

ggsave("data/ranking_diario.png", p, width = 8, height = 5, dpi = 150)

message("Ranking generado en data/ranking_diario.png")
