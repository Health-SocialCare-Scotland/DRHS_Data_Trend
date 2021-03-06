#Name: Drug Related Hospital Statistics (DRHS) Data trend page
#Author: Mike Smith
#Created: 24/01/2019
#Type: Data visualisation
#Written on: RStudio
#Written for: R version 3.5.1 
#Output: Shiny application

#Descripion: The Data Trend page is a one-page shiny app that is intended to give a high 
#level overview of data at at the level of Scotland, health boards or Alcohol and
#Drug Partnerships (ADP's). It is intended to mirror some of the functionality 
#of the current transformed publications data trend page. 

#There will be three charts in total in the data trend page
# - 1) Rates of Activity Measure (Stays/Patients/New Patients)
# - 2) Rates of Stays broken down by substance categories
# - 3) Rates of Patients broken down by Demographic measure (Age/Sex/Deprivation). 


#There will be intitially three options to choose from 
# - 1) Hospital/Clinical Type
# - 2) Geography Type
# = 3) Geography

#A fourth option will be used to 'toggle' between Age, Sex and SIMD for the 
#demographic charts. 

library(shiny)
library(dplyr)
library(plotly)
library(shinyWidgets)
library(forcats)
library(DT)
library(stringr)
library(shinyBS)
library(bsplus)

##############################################.
############## Data Input ----
##############################################.


#The current data is stored on the stats server in the SubstanceMisuse1 directory 
#Current approach to reading in data is to take the SPSS output and then cut it down to 
#size and then save as csv files for use. 


#Data to be used for explorer and trend pages
all_data<- readRDS("s06-temp09_num_rate_perc_r-shiny_rounded.RDS")
#need to rename the final column as value
all_data<-all_data %>% 
  rename("value" = value_Round)


#round the data to nearest two 
all_data <- all_data %>% mutate(value = round(value, 2))

#We will manually change the names of factors in R until we have an agreed 
#terminology for the hospital and clinical types. 

all_data<-all_data %>% 
  mutate(hospital_type= fct_recode(hospital_type, 
                                   "General acute"= "General acute (SMR01)",
                                   "Psychiatric" ="Psychiatric (SMR04)",
                                   "Combined gen acute/psych" = "Combined (General acute/Psychiatric)"))

all_data<-all_data %>% 
  mutate(clinical_type= fct_recode(clinical_type, 
                                   "Mental & behavioural (M&B)" = "Mental and Behavioural",
                                   "Overdose (OD)" = "Overdose",
                                   "Combined M&B/OD" = "Combined (Mental and Behavioural/Overdose)"))

         
activity_summary<-all_data %>% 
  filter(drug_type == "All", 
         age_group == "All",
         sex == "All",
         simd == "All", 
         measure == "Rate")

activity_summary<-activity_summary %>% 
  mutate(activity_type= fct_relevel(activity_type,rev))

#filter by drug type
drug_types<- as.character(unique(all_data$drug_type)[2:7])

drug_summary<- all_data %>% 
  filter(activity_type == "Stays",
         drug_type %in% drug_types,
         age_group == "All",
         sex == "All",
         simd == "All", 
         measure == "Rate") %>% 
  droplevels()

#filter by demography
demographic_summary<- all_data  %>% 
  filter(drug_type == "All",
         activity_type =="Patients",
         ((age_group != "All" & sex == "All" & simd =="All")|
            (age_group == "All" & sex != "All" & simd =="All")|
            (age_group == "All" & sex == "All" & simd !="All")), 
         measure == "Rate") 
demographic_summary <- demographic_summary %>%  
  mutate(sex= fct_relevel(sex,rev))


#we will also set user input options
hospital_types <- as.character(unique(activity_summary$hospital_type))
hospital_types<-c(hospital_types[3],hospital_types[1],hospital_types[2])
clinical_types <- as.character(unique(activity_summary$clinical_type))
clinical_types<-c(clinical_types[3],clinical_types[1],clinical_types[2])
locations <- as.character(unique(activity_summary$geography))
location_types<-list("Scotland" = locations[1],
                     "NHS Board of residence" = locations[2:15],
                     "ADP of residence" = locations[16:46])

demographic_types<-c("Age","Sex", "Deprivation")


#Colour blind friendly colour scheme - consult documentation


#Beginning of script
{
  ##############################################.
  ############## User Interface ----
  ##############################################.
  ui <- fluidPage(style = "width: 100%; height: 100%; max-width: 1200px;",
    
    
    titlePanel(title=div(img(src="ISD_NSS_logos.png",height = 96,
                             width = 223,
                             style = "float:right;"),
                         h1("Drug-Related Hospital Statistics"),
                         h4("Drug and Alcohol Misuse"), 
                         style = "height:96px;"),
               windowTitle = "Drug-Related Hospital Statistics"),
    tabPanel(title = "",
             
    style = "height: 95%; width: 95%; background-color: #FFFFFF;
    border: 0px solid #FFFFFF;",
    h1(tags$b("Trend data"), id= 'Top'),
    
    p(
      "The Trend data page provides an overview of drug-related hospital stays 
         in Scotland over time, based on the following charts: 
        ",
      tags$ul(
        tags$li(tags$a(href= '#activity_link',tags$b("Activity type")),
                " (stay rates, patient rates and new patient rates)"),
        tags$li(tags$a(href = '#drugs_link',  
                       tags$b("Drug type"))),
        tags$li(tags$a(href='#demographics_link', tags$b("Patient demographics")),
                " (Age/Sex/Deprivation - choose between these using the blue 
                buttons above the chart)")
      )),

    
      bs_accordion(id = "drhs_text") %>%
        bs_set_opts(panel_type = "primary") %>%
        bs_append(title = "data selection", 
                  content = p("The charts can be modified using the drop down boxes: ",
                  tags$ul(
                    tags$li("Hospital type: general acute or psychiatric hospital data 
                (or a combination);"),
                    tags$li("Clinical type: mental & behavioural stays, accidental 
                poisoning/overdose stays (or a combination); and,"),
                    tags$li("Location: data from Scotland, specific NHS Boards or 
                Alcohol and Drug Partnerships.")
                  )))%>% 
        bs_append(title = "Chart functions",
                  content = p("At the top-right corner of each chart, you will see
                              a toolbar with four buttons: ",
                    tags$ul(
                    tags$li(
                      icon("camera"),
                      tags$b("Download plot as a png"),
                      " - save an image of the chart (not available in 
                      Internet Explorer)."
                    ),
                    tags$li(
                      icon("search"),
                      tags$b("Zoom"),
                      " - click and drag within the chart area to focus 
                      on a specific part."
                    ),
                    tags$li(
                      icon("move", lib = "glyphicon"),
                      tags$b("Pan"),
                      " - click and move the mouse in any direction to 
                      modify the chart axes."
                    ),
                    tags$li(
                      icon("home"),
                      tags$b("Reset axes"),
                      " - click this button to return the axes to their
                      default range."
                    )
                    ), 
                  "Categories can be shown/hidden by clicking on labels 
                  in the legend to the right of each chart."))%>% 
    bs_append(title = "Table functions",
              content = p("To view your data selection in a table, use the
                            'Show/hide table' button below each chart.",
                          tags$ul(
                            tags$li(
                              icon("sort", lib = "glyphicon"),
                              tags$b("Sort"),
                              " - click to sort a table in ascending or descending 
                      order based on the values in a column. "
                            ),
                            tags$li(
                              tags$b("Page controls"),
                              " - switch to specific page of data within a table. "
                            )
                          ), 
                          "Categories can be shown/hidden by clicking on labels 
                  in the legend to the right of each chart."))
    
    ,
    
    p(
      HTML(paste0('A more detailed breakdown of these data is available in the <b> <a href="https://scotland.shinyapps.io/nhs-drhs-data-explorer/">Data explorer</a></b>.'))
     ) ,
    p(
      "If you experience any problems using this dashboard or have further
      questions relating to the data, please contact us at:",
      HTML(paste0('<b> <a href="mailto:NSS.isdsubstancemisuse@nhs.net">NSS.isdsubstancemisuse@nhs.net</a></b>.'))
    ),
    

    
    p(
      tags$b(
        "Note: Statistical disclosure control has been applied to protect
        patient confidentiality. Therefore, the figures presented here
        may not be additive and may differ from previous publications"
      )
    ),
    downloadButton(outputId = "download_glossary", 
                   label = "Download glossary", 
                   class = "glossary"),
    tags$head(
      tags$style(".glossary { background-color: #0072B2; } 
                          .glossary { color: #FFFFFF; }")
    ),

    p(""),

    
    wellPanel(
      tags$style(
        ".well { background-color: #FFFFFF;
        border: 0px solid #336699; }"
      ),
      
      #Insert the reactive filters. As location  is dependent on 
      #location type this part has to be set up in the server as a 
      #reactive object and then placed into the UI. 
      
      column(
        4,
        shinyWidgets::pickerInput(
          inputId = "Hospital_Type",
          label = "Hospital type",
          choices = hospital_types
        )
      ),
      
      column(
        4,
        shinyWidgets::pickerInput(
          inputId = "Clinical_Type",
          label = "Clinical type",
          choices = clinical_types
        )
      ),
      column(
        4,
        shinyWidgets::pickerInput(
          inputId = "Location",
          label = "Location",
          choices = location_types,
          options = list(size=5, 
                         `live-search`=TRUE)
        )
      )
    ),
   
    
    
    #In the main panel of the summary tab, insert the first plot
    br(),
    br(),
    h3("Activity type",id = 'activity_link'), 
    br(),
    
    mainPanel(
      width = 12,
      plotlyOutput("activity_summary_plot",
                   width = "1090px",
                   height = "600px"),
      HTML("<button data-toggle = 'collapse' href = '#activitysummary'
                   class = 'btn btn-primary' id = 'activitysummary_link'> 
                   <strong> Show/hide table </strong></button>"),
      HTML("<div id = 'activitysummary' class = 'collapse'>"),
      br(),
      dataTableOutput("activity_summary_table"),
      HTML("</div>"),
      br(),
      br()
    ),
    
    
    tags$head(
      tags$style(HTML("hr {border: 1px solid #000000;}"))
    ),
    
    p(
      
      br(),
      p("Main points (Scotland)",
      tags$ul(
        tags$li("Over the past 20 years, there was a fourfold increase in the 
                rate of drug-related general acute hospital stays within Scotland 
                (from 51 to 199 stays per 100,000 population), with a sharper 
                increase observed in recent years."),
        tags$li("After a lengthy period of stability, the rate of drug-related 
                psychiatric stays within Scotland increased from 29 to 40 stays per 100,000 
                population between 2014/15 and 2016/17, before decreasing slightly 
                in 2017/18 (38)."),
        tags$li("In 2017/18, 4,851 patients (90 new patients per 100,000 population) 
                were treated in hospital (general acute/psychiatric combined) for 
                drug misuse for the first time within Scotland. The drug-related new patient rate 
                has increased since 2006/07 (55 new patients per 100,000 population).")
      )),
      tags$a(href = '#Top',  
             icon("circle-arrow-up", lib= "glyphicon"),"Back to top"),
      hr()
      
    ), 
    h3("Drug type", id= 'drugs_link'),
  
    br(),
    br(),
    
    #then insert the drugs plot
    mainPanel(
      width = 12,
      plotlyOutput("drugs_plot",
                   width = "1090px",
                   height = "600px"),
      HTML("<button data-toggle = 'collapse' href = '#drugs'
                   class = 'btn btn-primary' id = 'drugs_link'> 
                   <strong> Show/hide table </strong></button>"),
      HTML("<div id = 'drugs' class = 'collapse'>"),
      br(),
      dataTableOutput("drugs_table"),
      HTML("</div>"),
      br(),
      br()
    ),
    p(
      
      br(),
      p("Main points (Scotland)",
      tags$ul(
        tags$li("In 2017/18, 58% of drug-related general acute stays within
                 Scotland were due 
                to opioids (drugs similar to heroin)."),
        tags$li("51% of drug-related psychiatric stays within Scotland were
                 associated with ‘multiple/other’ drugs  (including 
                hallucinogens, volatile solvents, multiple drug use and use of 
                other psychoactive substances (e.g. ecstasy)).")
      )),
      tags$a(href = '#Top',  
             icon("circle-arrow-up", lib= "glyphicon"),"Back to top"),
      hr()
      
    ),
    
    p(
      h3("Demographics", id= 'demographics_link')
    ), 
    
    
    #Insert demographic options 
    #This part to be converted into toggle button
    column(
      width = 5,
      shinyWidgets::radioGroupButtons(
        inputId = "summary_demographic",
        label = "Show: ",
        choices = demographic_types,
        status = "primary",justified = TRUE,
        checkIcon = list(yes = icon("ok", lib = "glyphicon")),
        selected = "Age"
      )
    ),
    #then final demographic plot
    mainPanel(
      width = 12,
      plotlyOutput("demographic_plot",
                   width = "1090px",
                   height = "600px"),
      HTML("<button data-toggle = 'collapse' href = '#demographic'
                   class = 'btn btn-primary' id = 'demographic_link'> 
                   <strong> Show/hide table </strong></button>"),
      HTML("<div id = 'demographic' class = 'collapse'>"),
      br(),
      dataTableOutput("demographic_table"),
      HTML("</div>"),
      br(),
      p(
        
        br(),
        p("Main points (Scotland)",
        tags$ul(
          tags$li("Drug-related hospital stays among individuals aged 35 and over
                  increased over the time series. For general acute stays among 
                  45-54 year olds, there was a greater than seventeen-fold increase 
                  from 12 to 208 patients per 100,000 population between 1996/97 
                  and 2017/18."),
          tags$li("Between 1996/97 and 2017/18, drug-related patient rates 
                  for males were approximately twice as high as 
                  female patient rates."),
          tags$li("In 2017/18, approximately half of patients with general 
                  acute or psychiatric stays in relation to drug misuse lived 
                  in the 20% most deprived areas in Scotland.")
        ), 
        tags$a(href = '#Top',  
               icon("circle-arrow-up", lib= "glyphicon"),"Back to top")
      ))
    )
    #End of UI part
  
  )  
  )  
  
  
  ##############################################.
  ############## Server ----
  ##############################################.
  
  
  #Beginning of server
  server  <-  function(input, output)
  {

    #Graph information text output
    output$text_output<-renderUI({ 
      p(HTML("Show/hide table - show data in a table below the chart."),
        
      p(HTML("At the top-right corner of the chart, 
             you will see a toolbar with four buttons:"),
        br(),
        tags$ul(
          tags$li(
            icon("camera"),
            tags$b("Download plot as a png"),
            " - click this button to save the graph as an image
            (please note that Internet Explorer does not support this
            function)."
          ),
          tags$li(
            icon("search"),
            tags$b("Zoom"),
            " - zoom into the graph by clicking this button and then
            clicking and dragging your mouse over the area of the
            graph you are interested in."
          ),
          tags$li(
            icon("move", lib = "glyphicon"),
            tags$b("Pan"),
            " - adjust the axes of the graph by clicking this button
            and then clicking and moving your mouse in any direction
            you want."
          ),
          tags$li(
            icon("home"),
            tags$b("Reset axes"),
            " - click this button to return the axes to their
            default range."
          )
          ),
        HTML("Categories can be shown/hidden by clicking on labels
             in the legend to the right of each chart.")
          ))
    })
    
    
    #we can then plot the graph based on the user input.
    #First we create a subset  of the data based on user input
    
    #For the activity summary
    activity_summary_new <- reactive({
      activity_summary %>%
        filter(
          hospital_type %in% input$Hospital_Type
          & clinical_type %in% input$Clinical_Type
          & geography %in% input$Location
        )%>%
        select(year,hospital_type, clinical_type, activity_type,geography,value)
    })
    
    #for the substances summary
    drug_summary_new <- reactive({
      drug_summary %>%
        filter(
          hospital_type %in% input$Hospital_Type
          & clinical_type %in% input$Clinical_Type
          & geography %in% input$Location
        )%>%
        select(year,hospital_type,clinical_type,drug_type,geography,value)
    })
    
    #for the demographic summary
    #as this is based on two files (and on two separate columns in one
    #file) then an if/else function is employed to select the correct data
    demographic_summary_new <- reactive({
      if (input$summary_demographic == "Age")
      {
        demographic_summary %>%
          filter(
            hospital_type %in% input$Hospital_Type
            & clinical_type %in% input$Clinical_Type
            & geography %in% input$Location
            & age_group != "All"
          )%>%
          select(year,hospital_type,clinical_type,geography,age_group,value)%>% 
          droplevels()
      }
      else if(input$summary_demographic == "Sex")
      {demographic_summary %>%
          filter(
            hospital_type %in% input$Hospital_Type
            & clinical_type %in% input$Clinical_Type
            & geography %in% input$Location
            & sex != "All"
          ) %>%
          select(year,hospital_type,clinical_type,geography,sex,value)%>% 
          droplevels()
        
      }
      else if (input$summary_demographic == "Deprivation")
      {
        demographic_summary %>%
          filter(hospital_type %in% input$Hospital_Type
                 & clinical_type %in% input$Clinical_Type
                 & geography %in% input$Location
                 & simd != "All"
          )%>%
          select(year,hospital_type,clinical_type,geography,simd,value)%>% 
          droplevels()
      }
    })
    
    
    #Then we can plot the actual graph, with labels
    
    #Activity Summary plot
    
    #Tooltip for graphs. 
    output$activity_summary_plot <- renderPlotly({
      #first the tooltip label
      tooltip_summary <- paste0(
        "Activity type: ", 
        activity_summary_new()$activity_type,
        "<br>",
        "Financial year: ",
        activity_summary_new()$year,
        "<br>",
        "Rate: ",
        formatC(activity_summary_new()$value, big.mark = ",",digits = 2,format = 'f')
        
      )
      
      #Create the main body of the chart.
      
      plot_ly(
        data = activity_summary_new(),
        #plot
        x = ~  year,
        y = ~  value,
        color = ~  activity_type,
        colors = c('#006ddb','#920000','#004949'),
        #tooltip
        text = tooltip_summary,
        hoverinfo = "text",
        #type
        type = 'scatter',
        mode = 'lines+markers',
        marker = list(size = 8),
        width = 1000,
        height = 600
      ) %>%
        
        #add in title to chart
       
      
      
        
        layout(title = list(text=
                              paste0(  input$Hospital_Type,
                            " hospital rates by activity type (",
                            input$Location,
                            "; ",
                            word(input$Clinical_Type,start = 1,sep = " \\("),
                            ")"),
                 font = list(size = 15)),
               
               separators = ".",
               annotations = 
                 list(x = 1.0, y = -0.25, 
                      text = paste0("Source: Drug-Related","<br>",
                                    "Hospital Statistics,","<br>",
                                    "ISD Scotland (",format(Sys.Date(), "%Y"),")"), 
                      showarrow = F, xref='paper', yref='paper', 
                      xanchor='left', yanchor='auto', xshift=0, yshift=0,
                      font=list(family = "arial", size=12, color="#7f7f7f")),
               
               yaxis = list(
                 
                 exponentformat = "none",
                 
                 separatethousands = TRUE,
                 
                 range = c(0, max(activity_summary_new()$value, na.rm = TRUE) +
                             (max(activity_summary_new()$value, na.rm = TRUE)
                              * 10 / 100)),
                 
                 title = paste0(c(
                   rep("&nbsp;", 20),
                   "EASR per 100,000 population",
                   rep("&nbsp;", 20),
                   rep("\n&nbsp;", 3)
                 ),
                 collapse = ""),
                 showline = TRUE,
                 ticks = "outside"
                 
               ),
               
               #Set the tick angle to minus 45. It's the only way for the x...
               #axis tick labels (fin. years) to display without overlapping...
               #with each other.
               #Wrap the x axis title in blank spaces so that it doesn't...
               #overlap with the x axis tick labels.
               
               xaxis = list(range = c(-1,22),
                            tickangle = -45,
                            title = paste0(c(rep("&nbsp;", 20),
                                             "<br>",
                                             "Financial year",
                                             rep("&nbsp;", 20),
                                             rep("\n&nbsp;", 3)),
                                           collapse = ""),
                            showline = TRUE,
                            ticks = "outside"),
               
               #Fix the margins so that the graph and axis titles have enough...
               #room to display nicely.
               #Set the font sizes.
               
               margin = list(l = 90, r = 60, b = 160, t = 90),
               font = list(size = 13),
               
               #insert legend
               showlegend = TRUE,
               legend = list(bgcolor = 'rgba(255, 255, 255, 0)',
                             bordercolor = 'rgba(255, 255, 255, 0)')) %>%
        
        #Remove unnecessary buttons from the modebar.
        
        config(displayModeBar = TRUE,
               modeBarButtonsToRemove = list('select2d', 'lasso2d', 'zoomIn2d',
                                             'zoomOut2d', 'autoScale2d',
                                             'toggleSpikelines',
                                             'hoverCompareCartesian',
                                             'hoverClosestCartesian'),
               displaylogo = F,  editable = F)
      
    })
    
    #Insert table
    output$activity_summary_table <- renderDataTable({
      datatable(activity_summary_new(),
                colnames = c("Financial year",
                             "Hospital type",
                             "Clinical type",
                             "Activity type",
                             "Location",
                             "Rate"),
                rownames = FALSE,
                style = "Bootstrap", 
                options = list(searching= FALSE,
                               lengthChange= FALSE)
                
      )%>% 
        formatRound(columns = 6,digits = 2)
    })
    
    # Substances Plot
    #Again start with the tooltip summary
    output$drugs_plot <- renderPlotly({
      #first the tooltip label
      tooltip_summary <- paste0(
        "Drug type: ",
        drug_summary_new()$drug_type,
        "<br>",
        "Financial year: ",
        drug_summary_new()$year,
        "<br>",
        "Rate: ",
        formatC(drug_summary_new()$value, big.mark = ",",
                digits = 2,format = 'f')
        
      )
      
      #Create the main body of the chart.
      
      plot_ly(
        data = drug_summary_new(),
        #plot
        x = ~  year,
        y = ~  value,
        color = ~  drug_type,
        colors = ~ c(
          '#004949',
          '#db6d00',
          '#ffb6db',
          '#006ddb',
          '#920000',
          '#b66dff' 
        ),
        #tooltip
        text = tooltip_summary,
        hoverinfo = "text",
        #type
        type = 'scatter',
        mode = 'lines+markers',
        marker = list(size = 8),
        width = 1000,
        height = 600
      )%>%
        
        #add in title to chart
        
        layout(title = list(
          text=
            paste0(  input$Hospital_Type,
                     " hospital stay rates by drug type (",
                     input$Location,
                     "; ",
                     word(input$Clinical_Type,start = 1,sep = " \\("),
                     ")"
        ),font = list(size = 15)),
               
               separators = ".",
               
               annotations = 
                 list(x = 1.0, y = -0.25, 
                      text = paste0("Source: Drug-Related","<br>",
                                    "Hospital Statistics,","<br>",
                                    "ISD Scotland (",format(Sys.Date(), "%Y"),")"), 
                      showarrow = F, xref='paper', yref='paper', 
                      xanchor='left', yanchor='auto', xshift=0, yshift=0,
                      font=list(family = "arial", size=12, color="#7f7f7f")),
               
               yaxis = list(
                 
                 exponentformat = "none",
                 
                 separatethousands = TRUE,
                 
                 range = c(0, max(drug_summary_new()$value, na.rm = TRUE) +
                             (max(drug_summary_new()$value, na.rm = TRUE)
                              * 10 / 100)),
                 
                 title = paste0(c(
                   rep("&nbsp;", 20),
                   "EASR per 100,000 population",
                   rep("&nbsp;", 20),
                   rep("\n&nbsp;", 3)
                 ),
                 collapse = ""),
                 showline = TRUE,
                 ticks = "outside"
                 
               ),
               
               #Set the tick angle to minus 45. It's the only way for the x...
               #axis tick labels (fin. years) to display without overlapping...
               #with each other.
               #Wrap the x axis title in blank spaces so that it doesn't...
               #overlap with the x axis tick labels.
               
               xaxis = list(range = c(-1,22),
                            tickangle = -45,
                            title = paste0(c(rep("&nbsp;", 20),
                                             "<br>",
                                             "Financial year",
                                             rep("&nbsp;", 20),
                                             rep("\n&nbsp;", 3)),
                                           collapse = ""),
                            showline = TRUE,
                            ticks = "outside"),
               font = list(size = 13),
               
               #Fix the margins so that the graph and axis titles have enough...
               #room to display nicely.
               #Set the font sizes.
               
               margin = list(l = 90, r = 60, b = 160, t = 90),
               
               
               #insert legend
               showlegend = TRUE,
               legend = list(bgcolor = 'rgba(255, 255, 255, 0)',
                             bordercolor = 'rgba(255, 255, 255, 0)')) %>%
        
        #Remove unnecessary buttons from the modebar.
        
        config(displayModeBar = TRUE,
               modeBarButtonsToRemove = list('select2d', 'lasso2d', 'zoomIn2d',
                                             'zoomOut2d', 'autoScale2d',
                                             'toggleSpikelines',
                                             'hoverCompareCartesian',
                                             'hoverClosestCartesian'),
               displaylogo = F,  editable = F)
      
    })
    
    output$drugs_table <- renderDataTable({
      datatable(drug_summary_new(),
                colnames = c("Financial year",
                             "Hospital type",
                             "Clinical type",
                             "Drug type",
                             "Location",
                             "Rate"),
                rownames = FALSE,
                style = "Bootstrap", 
                options = list(searching= FALSE,
                               lengthChange= FALSE)
      ) %>% 
        formatRound(columns = 6,digits = 2)
    })
    
    
    #Demographic Plot
    
    output$demographic_plot <- renderPlotly({
      #first the tooltip label
      tooltip_summary <- paste0(
        input$summary_demographic, ": ",
        demographic_summary_new()[,5],
        "<br>",
        "Financial year: ",
        demographic_summary_new()$year,
        "<br>",
        "Rate: ",
        formatC(demographic_summary_new()$value, big.mark = ",",
                digits = 2,format = 'f')
        
      )
      
      #Create the main body of the chart.
      
      plot_ly(
        data = demographic_summary_new(),
        #plot- we wont bother at this point with tailored colour
        x = ~  year,
        y = ~  value,
        color = ~  demographic_summary_new()[,5],
        colors = 
          if (input$summary_demographic == "Deprivation")
          {
            c("#b66dff",
              "#db6d00",
              "#920000",
              "#006ddb",
              "#490092"
              )
          }
        else if (input$summary_demographic == "Age")
        {
          c("#b66dff",
            "#db6d00",
            "#920000",
            "#006ddb",
            "#490092",
            "#6db6ff",
            "#b6dbff"
          )
        }
        else {
          c("#920000",
            "#006ddb")
        }
      
          
          ,
        #tooltip
        text = tooltip_summary,
        hoverinfo = "text",
        #type
        type = 'scatter',
        mode = 'lines+markers',
        marker = list(size = 8),
        width = 1000,
        height = 600
      )%>%
        
        #add in title to chart
        
        layout(title = list (text= (
          if (input$summary_demographic == "Deprivation")
          {
            paste0(  input$Hospital_Type,
                     " hospital patient rates by deprivation quintile (",
                     input$Location,
                     "; ",
                     word(input$Clinical_Type,start = 1,sep = " \\("),
                     ")")
          }
          else if (input$summary_demographic == "Age")
          {
            paste0(  input$Hospital_Type,
                     " hospital patient rates by age group (",
                     input$Location,
                     "; ",
                     word(input$Clinical_Type,start = 1,sep = " \\("),
                     ")")
          }
          else {
            paste0(  input$Hospital_Type,
                     " hospital patient rates by sex (",
                     input$Location,
                     "; ",
                     word(input$Clinical_Type,start = 1,sep = " \\("),
                     ")")
          }
        ),font = list(size = 15)),
               
               separators = ".",
        annotations = 
          list(x = 0.96, y = -0.29, 
               text = paste0("Source: Drug-Related","<br>",
                             "Hospital Statistics,","<br>",
                             "ISD Scotland (",format(Sys.Date(), "%Y"),")"), 
               showarrow = F, xref='paper', yref='paper', 
               xanchor='left', yanchor='auto', xshift=0, yshift=0,
               font=list(family = "arial", size=12, color="#7f7f7f")),
               
               yaxis = list(
                 
                 exponentformat = "none",
                 
                 separatethousands = TRUE,
                 
                 range = c(0, max(demographic_summary_new()$value, na.rm = TRUE) +
                             (max(demographic_summary_new()$value, na.rm = TRUE)
                              * 10 / 100)),
                 
                 title = paste0(c(
                   rep("&nbsp;", 20),
                   "EASR per 100,000 population",
                   rep("&nbsp;", 20),
                   rep("\n&nbsp;", 3)
                 ),
                 collapse = ""),
                 showline = TRUE,
                 ticks = "outside"
                 
               ),
               
               #Set the tick angle to minus 45. It's the only way for the x...
               #axis tick labels (fin. years) to display without overlapping...
               #with each other.
               #Wrap the x axis title in blank spaces so that it doesn't...
               #overlap with the x axis tick labels.
               
               xaxis = list(range = c(-1,22),
                            tickangle = -45,
                            title = paste0(c(rep("&nbsp;", 20),
                                             "<br>",
                                             "Financial year",
                                             rep("&nbsp;", 20),
                                             rep("\n&nbsp;", 3)),
                                           collapse = ""),
                            showline = TRUE,
                            ticks = "outside"),
               
               #        #Fix the margins so that the graph and axis titles have enough...
               #       #room to display nicely.
               #      #Set the font sizes.
               #
               margin = list(l = 90, r = 60, b = 160, t = 90),
               font = list(size = 13),
               
               #insert legend
               showlegend = TRUE,
               legend = list(
                 bgcolor = 'rgba(255, 255, 255, 0)',
                 bordercolor = 'rgba(255, 255, 255, 0)')) %>%
        
        #        #Remove unnecessary buttons from the modebar.
        
        config(displayModeBar = TRUE,
               modeBarButtonsToRemove = list('select2d', 'lasso2d', 'zoomIn2d',
                                             'zoomOut2d', 'autoScale2d',
                                             'toggleSpikelines',
                                             'hoverCompareCartesian',
                                             'hoverClosestCartesian'),
               displaylogo = F,  editable = F)
      
    })
    
    
    #Insert table
    output$demographic_table <- renderDataTable({
      datatable(demographic_summary_new(),
                rownames = FALSE,
                colnames = c("Financial year",
                             "Hospital type",
                             "Clinical type",
                             "Location",
                             input$summary_demographic,
                             "Rate"),
                style = "Bootstrap", 
                options = list(searching= FALSE,
                               lengthChange= FALSE)
      )%>% 
        formatRound(columns = 6,digits = 2)
      
       
    })
      
    #glossary link
    
      output$download_glossary <- downloadHandler(
        filename = 'glossary.pdf',
        content = function(file) {
          file.copy(paste0(filepath, "www/glossary.pdf"), file)
        }
      )
      
    #End of server
  }
  #End of script
}

shinyApp(ui = ui, server = server)
