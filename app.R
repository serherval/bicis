# app.R
#
# App Shiny para desplegar en Posit Connect Cloud (conectar el repo de GitHub
# directamente en connect.posit.cloud, sin configuración adicional de servidor).
#
# Lee el histórico directamente del CSV en GitHub (raw), así el scraper no
# necesita disparar un redeploy de la app en cada snapshot.

library(shiny)
library(dplyr)
library(readr)
library(plotly)
library(leaflet)

# EDITA: cambia tu-usuario/tu-repo por los reales
RAW_URL <- "https://raw.githubusercontent.com/tu-usuario/tu-repo/main/data/biki_history.csv"

ui <- fluidPage(
  titlePanel("BIKI Valladolid — Histórico"),
  sidebarLayout(
    sidebarPanel(
      selectInput("barrio", "Barrio", choices = c("Todos" = "")),
      selectInput("parada", "Parada", choices = NULL, multiple = TRUE)
    ),
    mainPanel(
      leafletOutput("mapa", height = 300),
      plotlyOutput("evolucion")
    )
  )
)

server <- function(input, output, session) {

  hist_data <- reactivePoll(
    intervalMillis = 5 * 60 * 1000,  # comprueba cada 5 min si hay datos nuevos
    session = session,
    checkFunc = function() Sys.time(),
    valueFunc = function() {
      read_csv(RAW_URL, show_col_types = FALSE) %>%
        mutate(total_bicis = mecanicas + electricas)
    }
  )

  observe({
    barrios_disponibles <- sort(unique(hist_data()$barrio))
    updateSelectInput(session, "barrio",
                       choices = c("Todos" = "", setNames(barrios_disponibles, barrios_disponibles)))
  })

  observeEvent(input$barrio, {
    d <- hist_data()
    if (input$barrio != "") d <- d %>% filter(barrio == input$barrio)
    opciones <- sort(unique(d$nombre))
    updateSelectInput(session, "parada", choices = opciones)
  })

  filtrado <- reactive({
    d <- hist_data()
    if (!is.null(input$barrio) && input$barrio != "") d <- d %>% filter(barrio == input$barrio)
    if (length(input$parada) > 0) d <- d %>% filter(nombre %in% input$parada)
    d
  })

  output$evolucion <- renderPlotly({
    plot_ly(filtrado(), x = ~timestamp, y = ~total_bicis, color = ~nombre,
            type = "scatter", mode = "lines+markers") %>%
      layout(yaxis = list(title = "Bicis disponibles"), xaxis = list(title = ""))
  })

  output$mapa <- renderLeaflet({
    ultimo <- filtrado() %>% filter(timestamp == max(timestamp))
    leaflet(ultimo) %>%
      addTiles() %>%
      addCircleMarkers(~lon, ~lat, radius = ~sqrt(total_bicis) * 2,
                        popup = ~paste0(nombre, ": ", total_bicis, " bicis"))
  })
}

shinyApp(ui, server)
