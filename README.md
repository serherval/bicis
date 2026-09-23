# BIKI Valladolid — histórico y estadísticas

Scraper automático + histórico + dashboard para el sistema de bicicletas
públicas BIKI de Valladolid.

## Estructura del repo

```
biki-valladolid/
├── .github/workflows/scrape.yml   → cron que ejecuta todo (9h, 14h, 19h)
├── scripts/
│   ├── scrape_biki.R              → descarga snapshot y lo añade al histórico
│   └── generar_ranking.R          → genera el PNG del top 10 para X/Twitter
├── data/
│   ├── barrios_valladolid.geojson → TÚ lo añades (ver paso 3)
│   ├── biki_history.csv           → se genera solo, no lo toques a mano
│   └── ranking_diario.png         → se genera solo en cada ejecución
├── docs/
│   └── index.html                 → dashboard estático, servido por GitHub Pages
├── dashboard.Rmd                  → fuente del dashboard de docs/index.html
├── app.R                          → app Shiny para desplegar en Connect Cloud
└── README.md
```

## Puesta en marcha (una sola vez)

1. **Crea el repo en GitHub** (público, para que los Actions sean gratis sin
   límite) y sube todo este contenido.

2. **No necesitas editar nada en `scripts/scrape_biki.R`** salvo, opcionalmente,
   `COL_BARRIO` una vez tengas el geojson de barrios (paso 3). El scraper
   llama directamente al feed GBFS oficial de BIKI
   (`valladolid.publicbikesystem.net`), publicado por el propio operador
   a través de los datos abiertos de AUVASA — no hay ningún servidor
   intermedio que montar.

3. **Descarga el geojson de barrios** de Valladolid desde el portal de datos
   abiertos del Ayuntamiento y guárdalo como
   `data/barrios_valladolid.geojson`. Abre el archivo y comprueba el nombre
   real de la columna con el nombre del barrio (puede que no sea `NOMBRE`);
   ajústalo en `scripts/scrape_biki.R` (variable `COL_BARRIO`).

4. **Activa GitHub Pages**: Settings → Pages → Source: rama `main`,
   carpeta `/docs`. Tu dashboard quedará en
   `https://tu-usuario.github.io/tu-repo/`.

5. **Lanza el workflow a mano una vez** (pestaña Actions → "Scrape BIKI
   Valladolid" → Run workflow) para comprobar que todo corre sin errores
   antes de esperar al cron.

6. **Conecta Connect Cloud** (connect.posit.cloud): "New content" → conecta
   este repo de GitHub → selecciona `app.R`. Antes, edita en `app.R` la línea
   ```r
   RAW_URL <- "https://raw.githubusercontent.com/tu-usuario/tu-repo/main/data/biki_history.csv"
   ```
   con tu usuario/repo reales. Connect Cloud redespliega solo con cada push,
   aunque al leer el CSV en caliente por HTTP no debería ni hacer falta.

## Fuente de los datos

`scripts/scrape_biki.R` llama a tres feeds GBFS oficiales, sin ningún
intermediario:

- `.../station_information` — nombre, lat/lon y capacidad de cada estación
- `.../station_status` — bicis disponibles por tipo y docks libres, en tiempo real
- `.../vehicle_types` — diccionario para saber qué `vehicle_type_id` es mecánica
  (`propulsion_type: "human"`) y cuál eléctrica (`"electric"`)

Al ser el feed oficial del operador (no una API comunitaria de terceros),
es la fuente más fiable posible: sin dependencia de que un tercero mantenga
su propia reinterpretación de los datos.

## Uso diario

No tienes que hacer nada más: el cron de GitHub Actions corre solo. Puedes
revisar `data/ranking_diario.png` tras cada ejecución para publicarlo a
mano en X, o automatizarlo más adelante si te compensa lidiar con los
límites de la API de X.

## Cosas a vigilar

- El cron está en UTC; con el cambio de hora en España te desviarás 1h
  respecto a las 9h/14h/19h reales medio año. Ajusta si te importa la
  precisión.
- Si el histórico crece mucho (años de datos), valora particionar
  `biki_history.csv` por mes para que git no se ralentice.
