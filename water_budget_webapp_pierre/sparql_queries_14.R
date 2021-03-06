# Link for graph database https://terminology.internetofwater.app
# alterantive https://wtc-gdb.internetofwater.app/  

# Import packages
library(tidyverse)
library(rdflib)
library(jsonlite)
library(d3r)
#devtools::install_github("vsenderov/rdf4r")
library(rdf4r)

# Load and parse TTL file from graphDB
file <- basic_triplestore_access("https://terminology.internetofwater.app", repository="WaterBudgetingFramework_v2_core")

#***************************************************#
#***** I. TABS - COMPONENT, STATE, DATA SOURCE *****#
#***************************************************#

# ----- 1. Creating dataframe for flow and component-subcomponent info ----- #
query_component <- "PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>

SELECT ?jL ?cL ?c ?fsourceL ?fsource ?fsinkL ?fsink ?ftypeL ?ftype ?scL ?sc ?pscL ?psc ?exmL ?exm WHERE {
    ?c wb:usedBy ?j.
    ?j rdfs:label ?jL.
    ?c rdfs:label ?cL.
    ?c rdf:type wb:Component.
    
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
    ?c skos:isExactMatch ?exm.
    ?exm rdfs:label ?exmL.
    }
}
"

# Submit query to get a dataframe
df_component_full <- submit_sparql(query_component,access_options=file)

# Assign NA to empty values
df_component_full[df_component_full == ""] <- NA

# Remove rows with components not having state name at the end "-__"
df_component_full <- df_component_full[grepl("-[A-Z]*", df_component_full$cL),]

# Similarly remove rows with subcomponents, partial subcomponents and exact matches without state names at the end

#--- For subcomponents
# get row number for which subcomponents are not NAs
index_NA <- which(is.na(df_component_full$scL), arr.ind=TRUE)
# get row numbers for which subcomponents do have a state at the end of their name
index_state <- which(grepl("-[A-Z]*", df_component_full$scL), arr.ind=TRUE)
# keep those rows
df_component_full <- df_component_full[c(index_NA, index_state),]

#--- For partial subcomponents
# get row number for which partial subcomponents are not NAs
index_NA <- which(is.na(df_component_full$pscL), arr.ind=TRUE)
# get row numbers for which parrtial subcomponents do have a state at the end of their name
index_state <- which(grepl("-[A-Z]*", df_component_full$pscL), arr.ind=TRUE)
# keep those rows
df_component_full <- df_component_full[c(index_NA, index_state),]

#--- For exact matches
# get row number for which exact matches are not NAs
index_NA <- which(is.na(df_component_full$exmL), arr.ind=TRUE)
# get row numbers for which exact matches do have a state at the end of their name
index_state <- which(grepl("-[A-Z]*", df_component_full$exmL), arr.ind=TRUE)
# keep those rows
df_component_full <- df_component_full[c(index_NA, index_state),]

# Sort column values in ascending order
df_component_full <- arrange(df_component_full, jL, cL, fsourceL, fsinkL, ftypeL, scL, pscL, exmL)

# Replace NMSOE for New Mexico to NM
df_component_full$cL <- gsub("-NMOSE","-NM", df_component_full$cL)

# Only keep the rows that are associated to the 5 US states (excluding Australia and US river basins)
df_component_full <- df_component_full[grep(".-CA|.-CO|.-NM|.-UT|.-WY", df_component_full$cL),] 

# Remove state names from components
df_component_full$cL <- gsub("-[A-Z][A-Z]","", df_component_full$cL)

# Remove URIs and store in a new dataframe
df_component_flow <- df_component_full[c(1,2,(seq(4,length(df_component_full), 2)))]

# Save as CSVs
write_csv(df_component_full, "www/df_component_full3.csv")
write_csv(df_component_flow, "www/df_component_flow3.csv")


# ---- 2. creating dataframe state-wise info ---- #

process_graphDB_state <- function(state){
  
    # Query for components that are directly linked to estimation methods, parameters, or data sources
    query_state_c2em <- paste0("PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX onto: <http://www.ontotext.com/>
    
    SELECT ?jL ?cL ?emL FROM onto:explicit WHERE {
        ?c wb:usedBy ?j.
        ?j rdfs:label ?jL.
        ?c rdfs:label ?cL.
        ?c rdf:type wb:Component.
        
        OPTIONAL {
        ?c wb:hasEstimationMethod ?em.
        ?em rdf:type wb:EstimationMethod.
        ?em rdfs:label ?emL.
        }
        FILTER regex(?jL, '", state, "')
    }")
    
    query_state_c2p <- paste0("PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX onto: <http://www.ontotext.com/>
    
    SELECT ?jL ?cL ?pL FROM onto:explicit WHERE {
        ?c wb:usedBy ?j.
        ?j rdfs:label ?jL.
        ?c rdfs:label ?cL.
        ?c rdf:type wb:Component.
        
        OPTIONAL {
        ?c wb:hasParameter ?p.
        ?p rdf:type wb:Parameter.
        ?p rdfs:label ?pL.
        #?em wb:usedBy ?state. #after adding this line, number of rows increasedby about 100 O_O
        }
        FILTER regex(?jL, '", state, "')
    }")
    
    query_state_c2ds <- paste0("PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX onto: <http://www.ontotext.com/>
    
    SELECT ?jL ?cL ?dsL FROM onto:explicit WHERE {
        ?c wb:usedBy ?j.
        ?j rdfs:label ?jL.
        ?c rdfs:label ?cL.
        ?c rdf:type wb:Component.
        
        OPTIONAL {
        ?c wb:hasDataSource ?ds.
        ?ds rdf:type wb:DataSource.
        ?ds rdfs:label ?dsL.
        #?p wb:usedBy ?state.
        ?ds wb:usedBy ?state.
        ?state rdfs:label ?stateL.
        
        #FILTER (?stateL = ?jL)
        }
        
        FILTER regex(?jL, '", state, "')
    }")
    
    query_state_em2p <- paste0("
    PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX onto: <http://www.ontotext.com/>
    
    SELECT ?jL ?emL ?pL FROM onto:explicit WHERE { 
    
        ?em wb:usedBy ?j.
        ?j rdfs:label ?jL.
        ?em rdfs:label ?emL.
        ?em rdf:type wb:EstimationMethod.
        
        OPTIONAL{
        ?em wb:hasParameter ?p.
        ?p rdf:type wb:Parameter.
        ?p rdfs:label ?pL.
        }
        
        FILTER regex(?jL, '", state, "')
    }
    ")
    
    query_state_p2ds <- paste0("
    PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX onto: <http://www.ontotext.com/>
    
    SELECT ?jL ?pL ?dsL ?stateL FROM onto:explicit WHERE { 
    
        ?p wb:usedBy ?j.
        ?j rdfs:label ?jL.
        ?p rdfs:label ?pL.
        ?p rdf:type wb:Parameter.
        
        OPTIONAL{
        ?p wb:hasDataSource ?ds.
        ?ds rdf:type wb:DataSource.
        ?ds rdfs:label ?dsL.
        ?ds wb:usedBy ?state.
        ?state rdfs:label ?stateL.
        }
        
        
        FILTER regex(?jL, '", state, "')
        #FILTER (?stateL = ?jL)
    }
    ")
    
    query_state_em2ds <- paste0("
    PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX onto: <http://www.ontotext.com/>
    
    SELECT ?jL ?emL ?dsL ?stateL FROM onto:explicit WHERE {
    
        ?em wb:usedBy ?j.
        ?j rdfs:label ?jL.
        ?em rdfs:label ?emL.
        ?em rdf:type wb:EstimationMethod.
    
        OPTIONAL {
        ?em wb:hasDataSource ?ds.
        ?ds rdf:type wb:DataSource.
        ?ds rdfs:label ?dsL.
        ?ds wb:usedBy ?state.
        ?state rdfs:label ?stateL.
        }
        
    
        FILTER regex(?jL, '", state, "')
        #FILTER (?stateL = ?jL)
    }
    ")
    
    # Converting to dataframe
    df_state_c2em <- submit_sparql(query_state_c2em,access_options=file)
    df_state_c2em[df_state_c2em == ""] <- NA  #assign NA to blank cells
    df_state_c2p <- submit_sparql(query_state_c2p,access_options=file)
    df_state_c2p[df_state_c2p == ""] <- NA
    df_state_c2ds <- submit_sparql(query_state_c2ds,access_options=file)
    df_state_c2ds[df_state_c2ds == ""] <- NA
    df_state_em2p <- submit_sparql(query_state_em2p,access_options=file)
    df_state_em2p[df_state_em2p == ""] <- NA
    df_state_p2ds <- submit_sparql(query_state_p2ds,access_options=file)
    df_state_p2ds[df_state_p2ds == ""] <- NA
    df_state_em2ds <- submit_sparql(query_state_em2ds,access_options=file)
    df_state_em2ds[df_state_em2ds == ""] <- NA
    
    # Get components with no estimation methods
    na_c2em <- df_state_c2em[which(is.na(df_state_c2em$emL), arr.ind=TRUE),]$cL
    # Get components with no parameters
    na_c2p <- df_state_c2p[which(is.na(df_state_c2p$pL), arr.ind=TRUE), ]$cL
    # Get components with no data sources
    na_c2ds <- df_state_c2ds[which(is.na(df_state_c2ds$dsL), arr.ind=TRUE), ]$cL
    # Intersect the 3 dataframes to get components with no estimation methods, parameters and data sources
    common_na <- intersect(intersect(na_c2em, na_c2p), na_c2ds)
    
    # Drop rows with no info
    if (length(common_na) > 0){
      df_state_c2em <- df_state_c2em[-which(df_state_c2em$cL %in% common_na),]
      df_state_c2p <- df_state_c2p[-which(df_state_c2p$cL %in% common_na),]
      df_state_c2ds <- df_state_c2ds[-which(df_state_c2ds$cL %in% common_na),]
    }
    
    # Replace NAs with "Unknown" value
    df_state_c2em$emL <- replace_na(df_state_c2em$emL,"Unknown")
    df_state_c2p$pL <- replace_na(df_state_c2p$pL,"Unknown")
    df_state_c2ds$dsL <- replace_na(df_state_c2ds$dsL,"Unknown")
    df_state_em2p$pL <- replace_na(df_state_em2p$pL,"Unknown")
    df_state_p2ds$dsL <- replace_na(df_state_p2ds$dsL,"Unknown")
    df_state_em2ds$dsL <- replace_na(df_state_em2ds$dsL,"Unkown")
    
    # The above 5 dataframes will be used to filter the master dataframe (df) below
    
    # Query for components that are  linked in sequential chain (not directly linked)
    query_state <- paste0("
    PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX onto: <http://www.ontotext.com/>
        
    SELECT ?jL ?cL ?emL ?pL ?dsL ?stateL FROM onto:explicit WHERE { #removed from onto:explicit
        ?c wb:usedBy ?j.
        ?j rdfs:label ?jL.
        ?c rdfs:label ?cL.
        ?c rdf:type wb:Component.
        
        OPTIONAL {
          ?c wb:hasEstimationMethod ?em.
          ?em rdf:type wb:EstimationMethod.
          ?em rdfs:label ?emL.
        }
        
        OPTIONAL {
          ?em wb:hasParameter ?p.
          ?p rdf:type wb:Parameter.
          ?p rdfs:label ?pL.
          #?em wb:usedBy ?state. #after adding this line, number of rows increasedby about 100 O_O
        }
        
        OPTIONAL {
          ?p wb:hasDataSource ?ds.
          ?ds rdf:type wb:DataSource.
          ?ds rdfs:label ?dsL.
          #?p wb:usedBy ?state.
          ?ds wb:usedBy ?state.
          ?state rdfs:label ?stateL.
        }
        
        FILTER regex(?jL, '", state, "')
    }
    ")
    
    # Submit query to get a dataframe, returns 3 millions relationships
    df <- submit_sparql(query_state,access_options=file)
    
    # Assign NA to empty values
    df[df == ""] <- "Unknown"
    
    # Check if the jurisdiction is same as the state usedBy property
    # get index for the rows where usedBy state is not same as jurisdiction 
    index <- which(!df$jL == df$stateL)
    # subset using the index
    df <- df[-c(index), ]
    
    
    # Drop column stateL
    df <- df[,-6]
    
    # Remove identical rows
    df <- unique(df)
    
    # for a specific component, we only want to keep rows that have those specific parameters
    
    # Get all unique components having at least 1 info
    unique_c <- unique(df_state_c2em$cL)
    
    # Make an empty dataframe to store filtered and processed dataframe
    df_state <- data.frame()
    
    for (i in 1:length(unique_c)){
      index_c <- which(df$cL == unique_c[i], arr.ind = TRUE) #get index of a specific component
      unique_em <- unique(df[c(index_c),3]) #for that component, get unique estimation methods
      n_em <- length(unique(unique_em)) #number of unique estimation methods
      
      # iterate through each estimation method
      for (j in 1:n_em){
        
        index_em <- which(df$emL == unique_em[j], arr.ind = TRUE) #get index for the estimation method in df
        check_df <- df_state_c2p[which(df_state_c2p$cL == unique_c[i]),] #subset parameter df for that specific component
        
        #if estimation method is unknown and parameter is also unknown, directly connect to data source using filtering dataframe for data source
        if (("Unknown" %in% check_df$pL) & ("Unknown" %in% df[index_em,3])) {
          print("1")
          direct_connect <- df_state_c2ds[which(df_state_c2ds$cL == unique_c[i]),]  
          direct_connect$emL <- "Unknown"
          direct_connect$pL <- "Unknown"
          direct_connect <- direct_connect[ ,c("jL", "cL", "emL", "pL", "dsL")] #rearrange columns
          #print(direct_connect)
          #print("yes")
          df_state <- rbind(df_state, direct_connect)
        }
        
        # this condition is to work with Irrigated Agriculture Depletions-NMOSE because df's parameter has unknown for an em, but df_state_c2p doesnt have unknown so it doesnt satisfy the 3 logical conditions below in else loop
        if (("Unknown" %in% df[index_c,4]) & !("Unknown" %in% check_df$pL)){ ######### 2nd condition returns TRUE TRUE and firstcondition returns FALSE TRUE TRUE...., apparently && only tests the first value.. :(
          print("2")
          new_row <- data.frame("",unique_c[i],"Unknown")
          names(new_row) <- c("jL", "cL", "pL")
          check_df <- rbind(check_df, new_row) #add new row with unknowns to the check_df 
          print(check_df)
        } 
        
        # rows where parameters match
        index_selected <- which(df$pL %in% check_df$pL & df$emL %in% unique_em[j] & df$cL %in% unique_c[i])
        abc <- df[index_selected, ]
        
        
        #Similarly for data source
        check_df <- df_state_c2ds[which(df_state_c2ds$cL == unique_c[i]),]
        
        if (("Unknown" %in% df[index_c,5]) & !("Unknown" %in% check_df$dsL)) { #probably there is no data source that will be unknown.
          new_row <- data.frame("", unique_c[i], "Unknown")
          names(new_row) <- c("jL", "cL", "dsL")
          check_df <- rbind(check_df, new_row)
        }
          
        # rows where parameters dont match, drop
        index_selected <- which(abc$dsL %in% check_df$dsL)
        abc <- abc[index_selected, ] 
        
        # Append to df_state dataframe
        df_state <- rbind(df_state, abc)
      }
    }
    
    
    # If some esitmation method of a component doesnt exist but directly linked to data sources or parameter
    # Filter stage 2
    unique_c <- unique(df_state$cL)
    
    for (i in 1:length(unique_c)){
      
      jL <- unique(df_state_c2p[which(df_state_c2p$cL == unique_c[i]),1])
      index_c <- which(df_state$cL == unique_c[i], arr.ind = TRUE) #get index of a specific component
      unique_em <- unique(df_state_c2em[c(index_c),3]) #get unique estimation methods for this component
      n_em <- length(unique(unique_em)) #number of unique estimation methods
      
      # Iterate through each estimation method
      for (j in 1:n_em){
        
        real_ds <- unique(df_state_em2ds[df_state_em2ds$emL == unique_em[j],3]) #get data sources that are linked to that em in filtering dataframe em2ds
        n_ds <- length(real_ds) #number of real data sources for that estimation method
        
        # Get index for rows that should be dropped, where data sources for that estmation method are not in filtering dataframe em2ds
        drop_index <- which(df_state$emL %in% unique_em[j] & !df_state$dsL %in% real_ds) #FOR Agricultural and Municipal Diversions-UT
        
        # If there is an index that should be dropped, drop it
        if (length(drop_index ) > 0) {
          df_state <- df_state[-c(drop_index),]
        }
    
      }
    }
    
    ####Next condition if a parameter is not in df but it is in c2p then add an unknown to its estimation method and keep it
    unique_c <- unique(df_state_c2em$cL)
    
    for (i in 1:length(unique_c)){
      jL <- unique(df_state_c2em[which(df_state_c2em$cL == unique_c[i]),1]) ############################returns nothing when I had "df" instead of "df_state_c2em" because Reservoir Evaporation-UT is not in main df
      index_c <- which(df$cL == unique_c[i], arr.ind = TRUE)
      real_p <- df_state_c2p[which(df_state_c2p$cL == unique_c[i]),3]
      
      for (j in 1: length(unique(real_p))){
        
        #print (df[index_c,4])
        #print (real_p[j])
        if (!real_p[j] %in% df[index_c,4]){ #check if a parameter is in c2p dataframe but not in the main df, if so add it
          ds <- df_state_p2ds[df_state_p2ds$pL == real_p[j], 3] # get the parameter's data sources from p2ds
          # might need to check if the data sources for this parameter in p2ds exists in c2ds in case it is not linked with the component
          # Iterate over each data source
          if (length(unique(ds)) > 0){
            for (k in 1:length(unique(ds))){
              new_row <- data.frame(jL, unique_c[i], "Unknown", real_p[j], ds[k])
              names(new_row) <- c("jL", "cL", "emL", "pL", "dsL")
              #df_state <- rbind(df_state, new_row)
              print(length(unique(real_p)))
              print(length(unique(ds)))
            }
          }
        }
      }
    }
    
    # Add a row to directly link a data source to the component (from c2ds), if it is not in em2ds or p2ds
    for (i in 1:length(unique_c)){
      jL <- unique(df_state_c2ds[which(df_state_c2ds$cL == unique_c[i]),1])
      
      components_EM <- df_state_c2em[which(df_state_c2em$cL == unique_c[i]),3] #get all the estimation method for the component
      components_P <- df_state_c2p[which(df_state_c2p$cL == unique_c[i]),3] #get all the parameter for the component
      
      data_sources_c2ds <- df_state_c2ds[which(df_state_c2ds$cL == unique_c[i]),3] #data sources from c2ds
      data_sources_em2ds <- df_state_em2ds[which(df_state_em2ds$emL %in% components_EM),3] #data sources from em2ds
      data_sources_p2ds <- df_state_p2ds[which(df_state_p2ds$pL %in% components_P),3] #data sources from p2ds
      
      for (j in 1:length(unique(data_sources_c2ds))){
        if ((!data_sources_c2ds[j] %in% data_sources_em2ds) & (!data_sources_c2ds[j] %in% data_sources_p2ds)){
          new_row <- data.frame(jL, unique_c[i], "Unknown", "Unknown", data_sources_c2ds[j])
          names(new_row) <- c("jL", "cL", "emL", "pL", "dsL")
          df_state <- rbind(df_state, new_row)
          print("TRUE")
        } else {
          print ("FALSE")
        }
        
      }
    }
    
    # Keep unique rows to prevent duplicate rows
    df_state <- unique(df_state)
    
    return (df_state)
}

# Process graph database for NM
df_state_ca <- process_graphDB_state("CA")
df_state_co <- process_graphDB_state("CO")
df_state_nm <- process_graphDB_state("NM")
df_state_ut <- process_graphDB_state("UT")
df_state_wy <- process_graphDB_state("WY")

# Combine all state's dataframeinto 1 dataframe
df_state <- rbind(df_state_ca, df_state_co, df_state_nm, df_state_ut, df_state_wy)

# Remove components usedBy river basins
#df_state <- df_state[(df_state$jL %in% c("CA", "CO", "NM", "UT", "WY")),]
#df_state <- df_state[grep(".-CA|.-CO|.-NMOSE|.-UT|.-WY", df_state$cL),] #Exclude NM

# Drop duplicate rows (for duplicate data sources)
#df_state <- unique(df_state)

# Data source tab
df_data_source <- select(df_state, -jL)
df_data_source <- df_data_source[,c(4,3,2,1)]
df_data_source$dsL <- gsub(",","", df_data_source$dsL)
write_csv(df_data_source, "www/df_data_source3.csv")

# Component tab
df_component <- arrange(df_state, jL, cL, emL, pL, dsL) # each column in ascending alphabetical order
df_component$cL <- gsub("-[A-Z][A-Z][A-Z][A-Z][A-Z]","", df_component$cL) #remove "-NMOSE" for New mexico in output
df_component$cL <- gsub("-[A-Z][A-Z]","", df_component$cL) # remove state initials from components
df_component$dsL <- gsub(",","", df_component$dsL)
write_csv(df_component, "www/df_component3.csv")

# State tab
df_state <- arrange(df_state, jL, cL, emL, pL, dsL) # each column in ascending alphabetical order
df_state$cL <- gsub("-[A-Z][A-Z][A-Z][A-Z][A-Z]","", df_state$cL)
df_state$cL <- gsub("-[A-Z][A-Z]","", df_state$cL) # remove state initials from components
df_state$dsL <- gsub(",","", df_state$dsL)
write_csv(df_state, "www/df_state3.csv")


#---- 3. Everything (including uri & excluding exact matches and subcomponent stuff) ----#
query <- "PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX onto: <http://www.ontotext.com/>

SELECT ?j ?jL ?c ?cL ?em ?emL ?p ?pL ?ds ?dsL ?stateL FROM onto:explicit WHERE {
    ?c wb:usedBy ?j.
    ?j rdfs:label ?jL.
    ?c rdfs:label ?cL.
    ?c rdf:type wb:Component.
    
    OPTIONAL {
    ?c wb:hasEstimationMethod ?em.
    
    #?em rdf:type wb:EstimationMethod.
    ?em rdfs:label ?emL.
    ?em wb:hasParameter ?p.
    #?em wb:usedBy ?state. #this line reduced the number of rows by 50
    
    #?p rdf:type wb:Parameter.
    ?p rdfs:label ?pL.
    ?p wb:hasDataSource ?ds.
    #?p wb:usedBy ?state.
    
    #?ds rdf:type wb:DataSource.
    ?ds rdfs:label ?dsL.
    ?ds wb:usedBy ?state.
    
    ?state rdfs:label ?stateL.
    }
    
    #FILTER (?stateL = ?jL) #if uncomment this, then comment the line below that drops rows where stateL != jL
    
}
"

# Submit query to get a dataframe
df <- submit_sparql(query,access_options=file)

# Assign NA to empty values
#df[df == ""] <- NA
df[df == ""] <- "Unknown" ######################################## after changing this I didnt re-export, so check this if there are more issues

# Check if the jurisdiction is same as the state usedBy property
# get index for the rows where usedBy state is not same as jurisdiction 
index <- which(!df$jL == df$stateL)
df <- df[-c(index), ]

# Drop column stateL
df <- df[,-11]

# Sort columns in ascending order
df <- arrange(df, cL, emL, pL, dsL) 

# Substitute comma with empty character
df$dsL <- gsub(",","", df$dsL)

# Export as a table
write.table(df, file = "./www/hyperlink3.csv", sep = ",",
            qmethod = "double", quote=FALSE, 
            row.name = FALSE)




#*********************************#
#***** II. TABS - INTERSTATE *****#
#*********************************#


# ----- 1. Exact Match ----- #

# Containing all the relevant flow information
# properties like flow type, flowsink and source are put in a separat optional tag for c and with the same optional tag for ex

query <- "PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
#PREFIX onto: <http://www.ontotext.com/>
#FROM onto:readwrite (insert at the end of SELECT statement)

SELECT ?state_cL ?ftype_cL ?fsource_cL ?fsink_cL ?cL ?exmL ?state_exmL ?ftype_exmL ?fsource_exmL ?fsink_exmL ?c ?exm WHERE {
    ?c wb:usedBy ?state_c.
    ?state_c rdfs:label ?state_cL.
    ?c rdfs:label ?cL.
    ?c rdf:type wb:Component.
    
  OPTIONAL {
    ?c skos:isExactMatch ?exm.
    ?exm rdfs:label ?exmL.
    ?exm wb:usedBy ?state_exm.
    ?state_exm rdfs:label ?state_exmL.
    
    ?exm wb:isFlowType ?ftype_exm.
    ?ftype_exm rdfs:label ?ftype_exmL.
    
    ?exm wb:flowSource ?fsource_exm.
    ?fsource_exm rdfs:label ?fsource_exmL.
    
    ?exm wb:flowSink ?fsink_exm.
    ?fsink_exm rdfs:label ?fsink_exmL.
  }
  
  OPTIONAL {
    ?c wb:isFlowType ?ftype_c.
    ?ftype_c rdfs:label ?ftype_cL.
  }
  
  OPTIONAL {
    ?c wb:flowSource ?fsource_c.
    ?fsource_c rdfs:label ?fsource_cL.
  }
  
  OPTIONAL {
    ?c wb:flowSink ?fsink_c.
    ?fsink_c rdfs:label ?fsink_cL.
  }
}
"

# Submit query to get a dataframe
df <- submit_sparql(query,access_options=file)

# Assign NA to empty values
df[df == ""] <- NA

# Remove rows with components not having state name at the end "-__"
df <- df[grepl("-[A-Z]*", df$cL),]

# Remove rows where exact matches do not have state name at the end
# get row number for which exact matches are not NAs
index_NA <- which(is.na(df$exmL), arr.ind=TRUE)
# get row numbers for which exact matches have a state at the end of their name
index_state <- which(grepl("-[A-Z]*", df$exmL), arr.ind=TRUE)
# keep those rows
df <- df[c(index_NA, index_state),] 

# Remove components usedBy river basins
df <- df[(df$state_cL %in% c("CA", "CO", "NM", "NMOSE", "UT", "WY")),]
df <- df[(df$state_exmL %in% c("CA", "CO", "NM", "NMOSE", "UT", "WY", NA)),]
df$empty <- NA

# Export as csv 
write_csv(df, "www/df_exact_match3.csv")


#---- 2. Subcomponent ----#
query <- "PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>

SELECT ?state_cL ?ftype_cL ?fsource_cL ?fsink_cL ?cL ?scL ?state_scL ?ftype_scL ?fsource_scL ?fsink_scL ?c ?sc WHERE {
    ?c wb:usedBy ?state_c.
    ?state_c rdfs:label ?state_cL.
    ?c rdfs:label ?cL.
    ?c rdf:type wb:Component.
  
  OPTIONAL {
    ?c wb:isSubComponentOf ?sc.
    ?sc rdfs:label ?scL.
    ?sc wb:usedBy ?state_sc.
    ?state_sc rdfs:label ?state_scL.
    
    ?sc wb:isFlowType ?ftype_sc.
    ?ftype_sc rdfs:label ?ftype_scL.
    
    ?sc wb:flowSource ?fsource_sc.
    ?fsource_sc rdfs:label ?fsource_scL.
    
    ?sc wb:flowSink ?fsink_sc.
    ?fsink_sc rdfs:label ?fsink_scL.
  }
    
  OPTIONAL {
    ?c wb:isFlowType ?ftype_c.
    ?ftype_c rdfs:label ?ftype_cL.
  }
  
  OPTIONAL {
    ?c wb:flowSource ?fsource_c.
    ?fsource_c rdfs:label ?fsource_cL.
  }
  
  OPTIONAL {
    ?c wb:flowSink ?fsink_c.
    ?fsink_c rdfs:label ?fsink_cL.
  }
}
"

# Submit query to get a dataframe
df <- submit_sparql(query,access_options=file)

# Assign NA to empty values
df[df == ""] <- NA

# Remove rows with components not having state name at the end "-__"
df <- df[grepl("-[A-Z]*", df$cL),]

# Remove rows where subcomponents do not have state name at the end
# get row number for which subcomponents are not NAs
index_NA <- which(is.na(df$scL), arr.ind=TRUE)
# get row numbers for which subcomponents have a state at the end of their name
index_state <- which(grepl("-[A-Z]*", df$scL), arr.ind=TRUE)
# keep those rows
df <- df[c(index_NA, index_state),] 

# Remove components usedBy river basins
df <- df[(df$state_cL %in% c("CA", "CO", "NM", "NMOSE", "UT", "WY")),]
df <- df[(df$state_scL %in% c("CA", "CO", "NM", "NMOSE", "UT", "WY", NA)),]
df$empty <- NA

# Export as CSV
write_csv(df, "www/df_subcomponent3.csv")


#---- 3. Partial Subcomponent ----#
query <- "PREFIX wb: <http://purl.org/iow/WaterBudgetingFramework/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>

SELECT ?state_cL ?ftype_cL ?fsource_cL ?fsink_cL ?cL ?pscL ?state_pscL ?ftype_pscL ?fsource_pscL ?fsink_pscL ?c ?psc WHERE {
    ?c wb:usedBy ?state_c.
    ?state_c rdfs:label ?state_cL.
    ?c rdfs:label ?cL.
    ?c rdf:type wb:Component.
  
  OPTIONAL {
    ?c wb:isPartialSubComponentOf ?psc.
    ?psc rdfs:label ?pscL.
    ?psc wb:usedBy ?state_psc.
    ?state_psc rdfs:label ?state_pscL.
    
    ?psc wb:isFlowType ?ftype_psc.
    ?ftype_psc rdfs:label ?ftype_pscL.
    
    ?psc wb:flowSource ?fsource_psc.
    ?fsource_psc rdfs:label ?fsource_pscL.
    
    ?psc wb:flowSink ?fsink_psc.
    ?fsink_psc rdfs:label ?fsink_pscL.
  }
    
  OPTIONAL {
    ?c wb:isFlowType ?ftype_c.
    ?ftype_c rdfs:label ?ftype_cL.
  }
  
  OPTIONAL {
    ?c wb:flowSource ?fsource_c.
    ?fsource_c rdfs:label ?fsource_cL.
  }
  
  OPTIONAL {
    ?c wb:flowSink ?fsink_c.
    ?fsink_c rdfs:label ?fsink_cL.
  }
}
"

# Submit query to get a dataframe
df <- submit_sparql(query,access_options=file)

# Assign NA to empty values
df[df == ""] <- NA

# Remove rows with components not having state name at the end "-__"
df <- df[grepl("-[A-Z]*", df$cL),]

# Remove rows where partial subcomponents do not have state name at the end
# get row number for which partial subcomponents are not NAs
index_NA <- which(is.na(df$pscL), arr.ind=TRUE)
# get row numbers for which partial subcomponents have a state at the end of their name
index_state <- which(grepl("-[A-Z]*", df$pscL), arr.ind=TRUE)
# keep those rows
df <- df[c(index_NA, index_state),] 

# Remove components usedBy river basins
df <- df[(df$state_cL %in% c("CA", "CO", "NM", "UT", "WY")),]
df <- df[(df$state_pscL %in% c("CA", "CO", "NM", "UT", "WY", NA)),]
df$empty <- NA

# Export as CSV
write_csv(df, "www/df_partial_subcomponent3.csv")

# ---X--- #
