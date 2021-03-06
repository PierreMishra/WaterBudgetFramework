library(shiny)
library(shinyjs)
library(tidyverse)
library(rdflib)
library(jsonlite)
library(d3r)

file <- rdf_parse("qrUilGBx2x8YZBCY6iSVG.ttl", format="turtle")

# ---- 1. creating dataframe for flow and subcomponent info ---- #
query_search <- "PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX : <http://webprotege.stanford.edu/project/qrUilGBx2x8YZBCY6iSVG#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>

SELECT ?jL ?cL ?fsourceL ?fsource ?fsinkL ?fsink ?ftypeL ?ftype ?scL ?sc ?pscL ?psc ?exmL ?exm WHERE {
    ?c wb:usedBy ?j.
    ?j rdfs:label ?jL.
    ?c rdfs:label ?cL.
    
    OPTIONAL{
    ?c wb:flowSource ?fsource.
    ?fsource rdfs:label ?fsourceL.
    }
    OPTIONAL{
    ?c wb:flowSink ?fsink.
    ?fsink rdfs:label ?fsinkL.
    }
    OPTIONAL{
    ?c wb:isFlowType ?ftype.
    ?ftype rdfs:label ?ftypeL.
    }
    OPTIONAL{
    ?c wb:isSubComponentOf ?sc.
    ?sc rdfs:label ?scL.
    }
    OPTIONAL{
    ?c wb:isPartialSubComponentOf ?psc.
    ?psc rdfs:label ?pscL.
    }
    OPTIONAL{
    ?c wb:isExactMatch ?exm.
    ?exm rdfs:label ?exmL.
    }
}
"

results_search <- rdf_query(file, query_search)
df_search_full <- as.data.frame(results_search)
df_search_full <- arrange(df_search_full, jL, cL, fsourceL, fsinkL, ftypeL, scL, pscL, exmL)
df_search_full$cL <- gsub("-[A-Z][A-Z]","", df_search_full$cL)
df_search_flow <- df_search_full[c(1,2,(seq(3,length(colnames(df_search_full)), 2)))]


# ---- 2. creating dataframe state-wise info ---- #
query_state <- "PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX : <http://webprotege.stanford.edu/project/qrUilGBx2x8YZBCY6iSVG#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>

SELECT ?jL ?cL ?emL ?pL ?dsL ?type WHERE {
    ?c wb:usedBy ?j.
    ?c rdf:type ?t.
    ?t rdfs:label ?type.
    ?j rdfs:label ?jL.
    ?c rdfs:label ?cL.
    OPTIONAL {
    ?c wb:hasEstimationMethod ?em.
    ?em rdfs:label ?emL.
    ?em wb:hasParameter ?p.
    ?p rdfs:label ?pL.
    ?p wb:hasDataSource ?ds.
    ?ds rdfs:label ?dsL.
    }
} HAVING (?type = 'Component')
" 

results_state <- rdf_query(file, query_state)
df_state <- as.data.frame(results_state) 
#df_state <- df_state[which(df_state$type == 'Component'),]# remove rows that have "type" other than "components"
#used SPARQL for selecting type as components
df_state <- select(df_state, -type)
df_state <- arrange(df_state, jL, cL, emL, pL, dsL)# each column in ascending alphabetical order
df_state$cL <- gsub("-[A-Z][A-Z]","", df_state$cL)#remove state initials from components



#drop-down choices
state_choices <- c("CA","CO","NM","UT")
component_choices <- c(unique(df_search_full$cL))

# Shiny app
ui <- fluidPage(id = "page", theme = "styles.css",
    useShinyjs(),
    tags$head(tags$link(href="https://fonts.googleapis.com/css2?family=Open+Sans+Condensed:wght@700&display=swap",
                        rel="stylesheet"),
              tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
              tags$script(src = "https://d3js.org/d3.v5.min.js"),
              tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.10.2/underscore.js"),
              tags$script(src = "index_v8.js")),
    tags$body(HTML('<link rel="icon", href="favicon.png",
                       type="image/png" />')), # add logo in the tab
    tags$div(class = "header",
             tags$img(src = "iow_logo.png", width = 60),
             tags$h1("IoW Water Budget Tool"),
             titlePanel(title="", windowTitle = "IoW Water Budget App")),
    navbarPage(title = "",
               selected = "Home",
               theme = "styles.css",
               fluid = TRUE,
      tabPanel(title = "Home"),
      
# ------ Tab - Search - Begin ------ # 
      tabPanel(title = "Search",
        column(width = 12,
          column(width = 3,
                 selectInput(inputId = "states1",
                             label = "Select state", 
                             choices = state_choices)),
          column(width = 3,
                 selectInput(inputId = "components",
                             label = "Select component",
                             choices = component_choices)),
          column(width = 2,
                 actionButton(inputId = "runButton1",
                              label = "",
                              icon = icon("check"))
                 )),
        tags$body(hidden(
                  tags$div(id = "search_summary",
                           style = "color:#777777",
                           tags$h3(tags$b(textOutput("component_title"))),
                           tags$p(htmlOutput("flow_source")),
                           tags$p(htmlOutput("flow_sink")),
                           tags$p(htmlOutput("flow_type")),
                           tags$p(htmlOutput("subcomponent")),
                           tags$p(htmlOutput("p_subcomponent")),
                           tags$p(htmlOutput("exact_match")),
                           tags$p(style = "font-size: 85%",
                                  tags$i("Estimation methods, 
                                         parameters and data sources 
                                         are presented below"))
                           )),
                  tags$div(id = "search_container"))
      ),
# ------ Tab - Search - End ------ #
      
# ------ Tab - State - Begin ------ #
      tabPanel(title = "State",
        column(width = 12,
          column(width = 3,
                 selectInput(inputId = "states2",
                             label = "Select state",
                             choices = state_choices)), #defined above UI
          column(width = 2, 
               actionButton(inputId = "runButton2", 
                            label = "",
                            icon = icon("check"))
               )),
        tags$body(tags$div(id = "state_sticky"),
                  tags$div(id = "state_container"))
    ),
# ------- Tab - State - End ------- #

    tabPanel(title = "Interstate"),
    navbarMenu(title = "About",
               tabPanel(title = "Other stuff"))
  ))

server <- function(input, output, session){
  
# Update component choices based on states you select
  observe({
    choices_components <- df_state %>%
      filter(jL %in% input$states1)
    choices_components <- c(unique(choices_components$cL))
    
    updateSelectInput(session, "components",
                      choices = choices_components)
  })
  
# Summary of component on Search tab
  observeEvent(input$runButton1, {
    # Show summary div
    show("search_summary")
    
    #Summary URIs
    df_uri <- df_search_full %>%
      filter(jL %in% input$states1) %>%
      filter(cL %in% input$components) %>%
      select(-c(1,2,3,5,7,9,11,13)) %>% #dropping jL, cL columns and retaining uri columns
      as.data.frame()
    
    #Summary information 
    component_info <- df_search_flow %>%
      filter(jL %in% input$states1) %>%
      filter(cL %in% input$components) %>%
      select(3:length(df_search_flow)) %>% #dropping jL, cL columns 
      as.data.frame()
    
    # URIs - storing multiple values as a list (to hyperlink each of them separately)
    
    uri_properties <- c("flow_source", "flow_sink", "flow_type",
                        "subcomponent", "p_subcomponent", "exact_match")
    
    uri_list <- paste("uri", uri_properties, sep="_")
    
    # for (i in seq(2,length(df_uri), 2)) {
    #   assign(paste(uri_list[i]), 
    #          paste(unlist(unique(df_uri[i]), use.names = FALSE), collapse=", "))
    # }
    
    #uri_list <- uri_list[-c(seq(1, length(uri_list), 2))] #remove empty variables
    
    # storing multiple URIs for 1 property in separate variables to later wrap as hyperlinks
    # for (i in 1:length(uri_list)){
    #   split_uri_values <- strsplit(get(uri_list[i]), "")[[1]]
    #   if ("," %in% split_uri_values) {
    #     split_uri <- unlist(strsplit(get(uri_list[i]), "[,]")) %>%
    #       trimws()
    #   } 
    # }
    
    # SUMMARY
    # Property names based on textOutput
    summary_properties <- c("flow_source", "flow_sink", "flow_type",
                    "subcomponent", "p_subcomponent","exact_match")
    
    # Create intermediary objects to hold unique strings from dataframe "component_info"
    # multiple values for a property are separated by commas
    summary_title <- paste(input$components, input$states1, 
                           sep = "-")
    summary_list <- paste("summary", summary_properties, sep="_")
    
    for (i in 1:length(summary_properties)) {
      assign(paste(summary_list[i]), 
             paste(unlist(unique(component_info[i]), use.names = FALSE), collapse=", "))
      
      assign(paste(uri_list[i]), 
             paste(unlist(unique(df_uri[i]), use.names = FALSE), collapse=", "))
    }
    
    # Render output
    output$component_title <- renderText(paste(summary_title))
    properties_display <- c("Flow Source:", "Flow Sink:", "Flow Type:",
                     "Subcomponent of:", "Partial Subcomponent of:","Exact Match:")
    
    # if an attribute has multiple values, it would add 1 hyperlink
    # to all values
    # so first we split each value and see if it has a comma
    # if it does then we assign split it by comma and store each value as a list in
    # a signle variable
    # then we run two different render options depending if a field has  a
    # single value or multiple value
    lapply(1:length(summary_list), function(i){
      split_property <- strsplit(get(summary_list[i]), "")[[1]]
      if ("," %in% split_property){
        split_value <- unlist(strsplit(get(summary_list[i]), "[,]")) %>%
          trimws()
        split_uri <- unlist(strsplit(get(uri_list[i]), "[,]")) %>%
          trimws()
        output[[summary_properties[i]]] <- renderText(paste("<b>", properties_display[i], "</b>",
                                              '<a href="', split_uri[1],'" target="_blank">',
                                              split_value[1], "</a>", 
                                              '<a href="', split_uri[2], '" target="_blank">',
                                              ",",
                                              split_value[2], "</a>"))
      }else if (get(summary_list[i]) == "NA") {
        output[[summary_properties[i]]] <- renderText(paste("<b>", properties_display[i], "</b>",
                                                    get(summary_list[i])))
      }else {
         output[[summary_properties[i]]] <- renderText(paste("<b>", properties_display[i], "</b>",
                                                    '<a href="', get(uri_list[i]),'" target="_blank">',
                                                    get(summary_list[i]), "</a>"))
      }
    })
    
    # lapply(1:length(properties_display), function(i){ 
    #   output[[properties[i]]] <- renderText(paste("<b>", properties_display[i], "</b>",
    #                                               '<a href=', uri_link,'target="_blank">',
    #                                               get(summary_list[i]), "</a>"))
#    }) #FOR loop cannot be used with render options

})

# Chart by component on search tab
  observeEvent(input$runButton1,{
    selection_df_1 <- df_state %>%
      filter(jL %in% input$states1) %>%
      filter(cL %in% input$components) %>%
      as.data.frame()
    selection_df_1 <- select(selection_df_1, -jL, -cL)
    selection_json_1 <- d3_nest(data = selection_df_1, root = "")
    leaf_nodes_1 <- nrow(selection_df_1)
    session$sendCustomMessage(type = "search_height", leaf_nodes_1)
    session$sendCustomMessage(type = "search_json", selection_json_1)
  })
  
# State charts on State tabs
  observeEvent(input$runButton2, {
    selection_df_2 <- df_state %>%
      filter(jL %in% input$states2) %>%
      as.data.frame()
    selection_df_2 <- select(selection_df_2, -jL)
    selection_json_2 <- d3_nest(data = selection_df_2, root = input$states2)
    leaf_nodes_2 <- nrow(selection_df_2)
    session$sendCustomMessage(type = "state_height", leaf_nodes_2)
    session$sendCustomMessage(type = "state_json", selection_json_2)
  })
}


shinyApp(ui = ui, server = server) 