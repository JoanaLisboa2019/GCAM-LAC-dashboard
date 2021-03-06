library(shiny)


# Dashboard Tab -----------------------------------------------------------

landingPageUI <- function(id) {
  ns <- NS(id)

  fluidRow(
    # Bar charts on far right
    column(4,
      div(style="display: inline-block;vertical-align:top; width: 150px;", h4("Choose a Scenario", inline=T)),
      div(style="display: inline-block;vertical-align:top; width: 150px;", selectInput(ns("dashScenario"), label = NULL, choices = list())),

      box(title = 'Primary Energy Consumption by Fuel', width = NULL,
         solidHeader = TRUE, status = "primary",
         plotOutput(ns("landingPlot1"), height='211px')
      ),
      box(title = 'GHG Emissions', width = NULL,
         solidHeader = TRUE, status = "primary",
         plotOutput(ns("landingPlot2"), height='211px')
      ),
      textOutput(ns('dashboardWarning'))
    ), # column

    # Tabbed box with water plots on far left
    column(4, align = "left",
      h4("Water"),
      uiOutput(ns('waterTabset')),

      div(align="center",
        conditionalPanel("output['dashboard-numYrs'] <= 3",
          radioButtons(ns('waterYearToggle'), NULL, choices = 0, inline = T)
        )
      ),
      conditionalPanel("output['dashboard-numYrs'] > 3",
        sliderInput(ns('waterYearSlider'), NULL, min=2005, max=2050,
                    value=2050, step=5, sep="")
      )
    ),

    # Tabbed box with agriculture and biomass plots in middle
    column(4, align = "left",

      h4("Land"),
      tabBox(id = ns("popTabset"), title = NULL, width = NULL, side = 'left',
        tabPanel("Crop Production", value = "Crops", plotOutput(ns("landPlot1"), height='500px')),
        tabPanel("Forest Cover", value = "Forest Cover", plotOutput(ns("landPlot2"), height='500px'))
      ),

      sliderInput(ns('popYear'), NULL, min=2005, max=2050, step=5, value=2020,
                  sep='', animate = F)
    )
  ) # fluidRow
} # landingPageUI


landingPage <- function(input, output, session, data) {

  # Update the landing page's senario select; default to the reference scenario
  observe({
    scens <- listScenarios(data()$proj)
    refscen <- grep("ref", scens, ignore.case = T, value = T)
    refscen <- if(length(refscen) > 0) refscen[1] else NULL
    updateSelectInput(session, 'dashScenario', choices=scens, selected=refscen)
  })

  output$dashboardWarning <- renderText({ data()$err })

  # Search for energy, water, and GHG queries in the input data
  observe({
    scen <- input$dashScenario
    if(scen %in% listScenarios(data()$proj)) {
      qs <- listQueries(data()$proj, scen)

      # ENERGY PLOTS
      primEnergy <- qs[grep("primary.*energy.*consumption", qs, ignore.case = T)][1]
      if(is.na(primEnergy))
        primEnergy <- qs[grep("primary.*energy", qs, ignore.case = T)][1]

      ghgByType <- qs[grep("ghg.*emissions.*type", qs, ignore.case = T)][1]
      if(is.na(ghgByType))
        ghgByType <- qs[grep("ghg.*emissions", qs, ignore.case = T)][1]

      filters <- list(region = lac.rgns)
      output$landingPlot1 <- renderPlot({
        pd <- isolate(data()$proj)
        plotTime(pd, primEnergy, scen, NULL, "fuel", filters)$plot +
          ggplot2::guides(fill = ggplot2::guide_legend(keyheight = 1.0,
                                                       keywidth = 1.0))
      })
      output$landingPlot2 <- renderPlot({
        pd <- isolate(data()$proj)
        plotTime(pd, ghgByType, scen, NULL, "gas_type", filters)$plot +
          ggplot2::guides(fill = ggplot2::guide_legend(keyheight = 1.0,
                                                       keywidth = 1.0))
      })

      # WATER PLOTS
      water <- qs[grep("water", qs, ignore.case = T)]
      water.grid <- sapply(water, function(q) { isGrid(data()$proj, scen, q) })
      if(any(water.grid)) water <- water[water.grid]
      if(length(water) > 3) water <- water[1:3] # limit to max 3 tabs

      output$waterTabset <- renderUI({
        tabs <- lapply(water, function(tabqry) {
          tabname <- sapply(strsplit(tabqry, " "), tail, 1)
          outputOptions(output, gsub(" ", "-", paste(tabqry, "plot")), suspendWhenHidden=FALSE)
          tabPanel(tabname, value = tabqry,
                   plotOutput(session$ns(gsub(" ", "-", paste(tabqry, "plot"))),
                              height = "500px"))
        })
        names(tabs) <- NULL
        do.call(tabBox, c(tabs, id = session$ns("waterTabBox"), width = 12))
      })
      outputOptions(output, 'waterTabset', suspendWhenHidden=FALSE)

      # Plots the maps in the newly constructed tabs
      lapply(water, function(query) {
        output[[gsub(" ", "-", paste(query, "plot"))]] <- renderPlot({
          nYrs <- 0
          if(uiStateValid(data()$proj, scen, query)) {
            nYrs <- getQuery(data()$proj, query, scen)$year %>% unique() %>%
                    length()
            year <- if(nYrs <= 3) as.integer(input$waterYearToggle) else input$waterYearSlider
            plotMap(data()$proj, query, scen, NULL, "lac", NULL, year)
          }
          else
            default.plot()
        })
      })
      outputOptions(output, gsub(" ", "-", paste(water[1], "plot")), suspendWhenHidden=FALSE)

      # Keeps track of whether to use a slider or a radio toggle
      output$numYrs <- reactive({
        nYrs <- 0
        query <- input$waterTabBox
        if(!is.null(query) && uiStateValid(data()$proj, scen, query))
          nYrs <- getQuery(data()$proj, query, scen)$year %>%
                  unique() %>% length()
        nYrs
      })
      outputOptions(output, "numYrs", suspendWhenHidden = FALSE)

      # When the map plots on the landing page are loaded, generate year toggle
      observe({
        query <- input$waterTabBox
        if(!is.null(query) && uiStateValid(data()$proj, scen, query)) {
          years <- getQuery(data()$proj, query, scen)$year %>% unique()

          selected <- median(years)

          if(length(years) > 3) {
            if(input$waterYearSlider %in% years)
              selected <- input$waterYearSlide # the previous selection
            updateSliderInput(session, 'waterYearSlider', NULL, value = selected)
          }
          else {
            if(input$waterYearToggle %in% years)
              selected <- input$waterYearToggle
            updateRadioButtons(session, 'waterYearToggle', NULL, choices = years,
                               selected = selected, inline = TRUE)
          }
        }
      })

      # LAND PLOTS
      land1 <- qs[grep("crop.*production", qs, ignore.case = T)][1]
      if(is.na(land1))
        land1 <- qs[grep("agriculture.*production", qs, ignore.case = T)][1]
      if(is.na(land1))
        land1 <- qs[grep("food.*", qs, ignore.case = T)][1]

      land2 <- qs[grep("land.*allocation", qs, ignore.case = T)][1]
      if(is.na(land2))
        land2 <- qs[grep("land.*", qs, ignore.case = T)][1]
      if(is.na(land2))
        land2 <- qs[grep("biomass.*", qs, ignore.case = T)][1]

      lapply(c("landPlot1", "landPlot2"), function(outputID) {
        output[[outputID]] <- renderPlot({
          query <- if(outputID == "landPlot1") land1 else land2
          filter <- if(outputID == "landPlot2") list(land_type = "Forest") else NULL
          year <- input$popYear
          plotMap(data()$proj, query, scen, NULL, "lac", filter, year)
        })
      })
    }
  })
}


# SSP Tab -----------------------------------------------------------------

scenarioComparisonUI <- function(id) {
  ns <- NS(id)

  tagList(

    fluidRow(
      column(4, selectInput(ns("sspChoices"), label = "Selected Scenarios", choices = list(),
                            multiple = TRUE)),
      column(4, selectInput(ns("sspCategory"), label = "Plot Variable", choices = list())),
      column(4, selectInput(ns("sspSubcat"), label = "Subcategory", choices = list('none')))
    ),

    fluidRow(
      box(width = 12, status = "primary", solidHeader = T,
          title = textOutput(ns('compQuery')),
          plotOutput(ns("sspComparison"), height = "520px", width = "100%"))
    )
  )
}

scenarioComparison <- function(input, output, session, data) {

  # When a new project is selected, update available scenarios
  observe({
    if(!is.null(data())) {
      scens <- listScenarios(data())
      updateSelectInput(session, 'sspChoices', choices = scens, selected = scens)
    }
  })

  observe({
    prj <- data()
    queries <- getScenarioQueries(prj, input$sspChoices)
    updateSelectInput(session, 'sspCategory', choices = queries, selected = queries[1])
  })

  # When a new query is selected, update available subcategories
  observe({
    prj <- data()
    if(!is.null(prj)) {
      cats <- getQuerySubcategories(prj, input$sspChoices[1], input$sspCategory)
      updateSelectInput(session, 'sspSubcat', choices = cats)
    }
  })

  # output$sspTitle <- renderUI({
  #   h3(input$sspCategory, align = "center")
  # })

  output$sspComparison <- renderPlot({
    query <- input$sspCategory
    scens <- input$sspChoices
    if(!uiStateValid(data(), scens[1], query)) {
      default.plot("No data")
    }
    else {
      output$compQuery <- renderText({query})
      # subcatvar <- tail(getQuerySubcategories(data(), scens[1], query), n=1)
      subcatvar <- getNewSubcategory(data(), scens[1], query, input$sspSubcat)
      plotScenComparison(data(), query, scens, NULL, subcatvar, lac.rgns)
    }
  })
}


# Region Filters ----------------------------------------------------------

regionFilterInput <- function(id) {
  ns <- NS(id)

  div(class = "box-overflow",
    box(title = "Filter by Region", status = "primary", solidHeader = TRUE,
      width = NULL, height = '580px', class = "box-overflow-y",
      actionButton(ns('rgnSelectAll'), 'Select all regions'),
      br(),

      bsCollapse(open="Latin America and Caribbean",
        bsCollapsePanel(title='Latin America and Caribbean', style="primary",
          actionButton(ns('rgns2All'), 'Deselect All'),
          checkboxGroupInput(ns('tvRgns2'), NULL, choices=lac.rgns, selected = lac.rgns)
        ),
        bsCollapsePanel(title="Africa",
          actionButton(ns('rgns1All'), 'Select All'),
          checkboxGroupInput(ns('tvRgns1'), NULL, choices=africa.rgns)
        ),
        bsCollapsePanel(title="Asia-Europe",
          actionButton(ns('rgns4All'), 'Select All'),
          checkboxGroupInput(ns('tvRgns4'), NULL, choices=europe.rgns)
        ),
        bsCollapsePanel(title="Asia-Pacific",
          actionButton(ns('rgns5All'), 'Select All'),
          checkboxGroupInput(ns('tvRgns5'), NULL, choices=asiapac.rgns)
        ),
        bsCollapsePanel(title="North America",
          actionButton(ns('rgns3All'), 'Select All'),
          checkboxGroupInput(ns('tvRgns3'), NULL, choices=north.america.rgns)
        )
      ) #bsCollapse
    ) # box
  ) # div
} # regionFilterInput


regionFilter <- function(input, output, session) {

  # When a 'select all' or 'deselect all' button is pressed, update region
  # filtering checkboxes
  observeEvent(input$rgns1All, {
    updateRegionFilter(session, 'rgns1All', 'tvRgns1', input$rgns1All%%2 == 0, africa.rgns)
  })
  observeEvent(input$rgns2All, {
    updateRegionFilter(session, 'rgns2All', 'tvRgns2', input$rgns2All%%2 == 1, lac.rgns) # starts with all checked
  })
  observeEvent(input$rgns3All, {
    updateRegionFilter(session, 'rgns3All', 'tvRgns3', input$rgns3All%%2 == 0, north.america.rgns)
  })
  observeEvent(input$rgns4All, {
    updateRegionFilter(session, 'rgns4All', 'tvRgns4', input$rgns4All%%2 == 0, europe.rgns)
  })
  observeEvent(input$rgns5All, {
    updateRegionFilter(session, 'rgns5All', 'tvRgns5', input$rgns5All%%2 == 0, asiapac.rgns)
  })
  observeEvent(input$rgnSelectAll, {
    # Select all
    sAll <- input$rgnSelectAll%%2 == 0
    updateRegionFilter(session, 'rgnSelectAll', 'tvRgns1', sAll, africa.rgns)
    updateRegionFilter(session, 'rgnSelectAll', 'tvRgns2', sAll, lac.rgns)
    updateRegionFilter(session, 'rgnSelectAll', 'tvRgns3', sAll, north.america.rgns)
    updateRegionFilter(session, 'rgnSelectAll', 'tvRgns4', sAll, europe.rgns)
    updateRegionFilter(session, 'rgnSelectAll', 'tvRgns5', sAll, asiapac.rgns)
  })

  return(reactive({c(input$tvRgns1, input$tvRgns2, input$tvRgns3, input$tvRgns4, input$tvRgns5)}))
}

#' Update the checkbox filters when select/deselect all button is pressed
#'
#' @param session The main session.
#' @param btnId The id of the actionButton that was pressed.
#' @param groupId The id of the checkboxGroupInput to act on.
#' @param selectAll If TRUE, select all checkboxes in the group defined by
#'   groupId. If not TRUE then deselect.
#' @param choices The labels of the checkboxes.
#' @export
updateRegionFilter <- function(session, btnId, groupId, selectAll, choices) {
  if(selectAll) {
    updateCheckboxGroupInput(session, groupId, choices = choices)
    newText <- "Select all"
  }
  else {
    updateCheckboxGroupInput(session, groupId, choices = choices, selected = choices)
    newText <- "Deselect all"
  }

  updateCheckboxInput(session, btnId, label = newText)
}


# Bar Chart Hover ---------------------------------------------------------

barChartHoverUI <- function(id) {
  ns <- NS(id)
  uiOutput(ns('hoverInfo'))
}

barChartHover <- function(input, output, session, hover, data, subcategory) {
  output$hoverInfo <- renderUI({
    hover <- hover()
    df <- data()
    subcat <- subcategory()

    val <- calculateHoverValue(hover, df, subcat)
    if(is.null(val)) return(NULL)


    # Calculate point position INSIDE the image as percent of total dimensions
    # from left (horizontal) and from top (vertical)
    left_pct <- (hover$x - hover$domain$left) / (hover$domain$right - hover$domain$left)
    top_pct <- (hover$domain$top - hover$y) / (hover$domain$top - hover$domain$bottom)

    # Calculate distance from left and bottom side of the picture in pixels
    left_px <- left_pct * (hover$range$right - hover$range$left) + hover$range$left
    top_px <- top_pct * (hover$range$bottom - hover$range$top) + hover$range$top

    left <- round(left_px) - 30
    top <- round(top_px) - 30
    if(left < 0 || top < 0) return(NULL)

    # Hover tooltip is created as absolutePanel
    absolutePanel(
      class = 'hoverPanel',
      left = paste0(left, "px"),
      top = paste0(top, "px"),
      p(HTML(val)))

  })
}

calculateHoverValue <- function(hover, df, subcat) {

  # Make sure we're working with valid values
  if(is.null(hover) || is.null(df)) return(NULL)

  # Detect the year of the bar that is being hovered over
  hoverYear <- df[which.min(abs(df$year - hover$x)), 'year'][[1]]
  df <- dplyr::filter(df, year == hoverYear)

  # If there are negative values (most likely from a diff plot), flip their
  # signs so we can use the same logic as we do for positive bars.
  y <- hover$y
  if(y < 0) {
    df <- df[which(df$value < 0), ]
    df$value <- abs(df$value)
    y <- abs(y)
  } else {
    df <- df[which(df$value > 0), ]
  }

  if(y > sum(df$value)) return(NULL) # Above the bar

  # If there's a subcategory, we also need to find which category is being
  # hovered over
  if(subcat == 'none') {
    val <- round(df$value, digits = 1) * sign(hover$y)
    as.character(val)
  }
  else {
    # Find which segment of the stacked bar the hover is closest to
    stackedSum <- sum(df$value) - cumsum(df$value)
    index <- which(stackedSum - y < 0)[1]

    # Get the region name and value for display
    regionName <- df[[subcat]][index]
    val <- round(df$value[index], digits = 1) * sign(hover$y)
    paste0(regionName, ': ', val)
  }
}

