#' @import rentrez
#' @import progress
library(dplyr)

setOldClass('gg')
setOldClass('ggplot')
setOldClass('gtable')

#' An S4 class to represent PubScore results
#' @slot terms_of_interest A list of terms of interest related to the topic you want to find the relevance.
#' @slot genes The genes to which you want to calculate and visualize the literature score.
#' @slot max_score The max score to use when calculating literature scores
#' @slot date The date when the object was initialized. PubScore counts will likely increase with time. 
#' @slot counts A data frame with the counts retrieved on PubMed
#' @slot network A visualization of the results found in a network
#' @slot heatmap A visualization of the results found in a heatmap
setClass(Class = 'PubScore', 
         slots = list(genes="character",
                      terms_of_interest = "character",
                      literature_score = "numeric",
                      max_score = "numeric",
                      date = "Date",
                      counts = "data.frame",
                      network = 'gg',
                      heatmap = 'gg',
                      all_counts = "data.frame",
                      total_genes = "character",
                      p_value = "numeric"))


setMethod('initialize', signature('PubScore'),
          function(.Object, genes, terms_of_interest){
            cat("~~~ Initializing PubScore ~~~ \n")
            .Object@genes <- genes
            .Object@terms_of_interest <- terms_of_interest  
             cts <- get_literature_score(genes, terms_of_interest)
            .Object@counts <- cts
            .Object@date <- Sys.Date()
            .Object@max_score <- Inf
            .Object@heatmap <- plot_literature_score(cts,
                       return_ggplot = TRUE,
                       is_plotly = FALSE)
            .Object@network <- plot_literature_graph(cts,
                         name = 'PubScore Network',
                         color = "#B30000FF",
                         n = 10)
            .Object@literature_score <- sum(cts$count) / (length(genes)*length(terms_of_interest))
            .Object@all_counts <- data.frame()
            .Object@total_genes <- 'empty'
            .Object@p_value <- Inf
            return(.Object)
            
          })
pub <- new(Class = "PubScore",genes = c('cd4','cd8'),terms_of_interest = c('blabla','immunity'))

#' Full PubScore analysis for visualization
#' @param terms_of_interest A list of terms of interest related to the topic you want to find the relevance for
#' @param genes A vector with multiple genes.
#' 
#' @return Object of class \code{PubScore}
#' @export

pubscore <- function(terms_of_interest, genes){
   results <- new(Class = "PubScore", genes, terms_of_interest)
   return(results)
}

#' Retrieve the heatmap attribute
#' @param pub Object of class \code{PubScore}
#' @return A "gg" object, from ggplot2, containing a heatmap from the counts table.
#' @examples
#' Create a new pubscore object
#' pub <- pubscore(genes = c('cd4','cd8'),terms_of_interest = c('blabla','immunity'))
#' plot(heatmapViz(pub))

#' @rdname heatmapViz
#' @export
setGeneric("heatmapViz", function(pub) {
  standardGeneric("heatmapViz")
})

#' @rdname heatmapViz
setMethod("heatmapViz", signature("PubScore"),
          function(pub){
            return(pub@heatmap)
          })


#' Retrieve the network attribute
#' @param pub Object of class \code{PubScore}
#' @return A "gg" object, from ggplot2, containing a network from the counts table.
#' @examples
#' Create a new pubscore object
#' pub <- pubscore(genes = c('cd4','cd8'),terms_of_interest = c('blabla','immunity'))
#' plot(networkViz(pub))

#' @rdname networkViz
#' @export
setGeneric("networkViz", function(pub) {
  standardGeneric("networkViz")
})

#' @rdname networkViz
setMethod("networkViz", signature("PubScore"),
          function(pub){
            return(pub@network)
          })

#' Auxiliary function for the test method 
.getSimulation_test <- function(pub, ambiguous = c(), n_simulations) {
  simulation_of_literature_null <-
    pub@all_counts[!pub@all_counts$Genes %in% ambiguous, ]
  
  n_genes <- length(pub@genes[!pub@genes %in% ambiguous ])
  total_genes <- levels(droplevels(simulation_of_literature_null$Genes))
  message(paste0('Running ', n_simulations,' simulations'))
  distribution_of_scores <- c()
  
  for (i in seq_len(n_simulations)) {
    genes_to_sample_now <- sample(total_genes, n_genes)
    simu_now <-
      simulation_of_literature_null[simulation_of_literature_null$Genes %in% genes_to_sample_now, ]$count
    list_score <- sum(simu_now) / (length(pub@genes)*length(pub@terms_of_interest))
    distribution_of_scores <- c(distribution_of_scores, list_score)
    
  }
  
  distribution_of_scores <- data.frame(d = distribution_of_scores)
  return(distribution_of_scores) 
  
}

#' Get and test the literature enrichment score
#' @param pub Object of class \code{PubScore}
#' @param total_genes A list of all the possible genes in your study. 
#' Usually all the names in the rows of an "exprs" object.
#' @param max_score Which score will be considered the maximum for a gene-term association. 
#' Reduces the contribution of genes with large literature enrichment. Defaults to Inf.
#' @param show_progress If TRUE, a progress bar is displayed. Defaults to True.
#' @param verbose If TRUE, will display the index of the search occuring. Defaults to false.
#' @param remove_ambiguous If TRUE, ambiguously named genes (such as "MARCH") will be removed. Defaults to TRUE.  
#' @param nsim The number of simulations to run. Defaults to 100000.
#' @return A "gg" object, from ggplot2, containing a network from the counts table.
#' @examples
#' Create a new pubscore object
#' pub <- pubscore(genes = c('cd4','cd8'),terms_of_interest = c('blabla','immunity'))
#' plot(test_score(pub))
#' @rdname test_score
#' @export
setGeneric("test_score", function(pub, total_genes,
                                  max_score = Inf,
                                  show_progress = TRUE,
                                  remove_ambiguous = TRUE,
                                  verbose = FALSE,
                                  nsim = 100000) {
  standardGeneric("test_score")
})

#' @rdname test_score
setMethod("test_score", signature("PubScore"),
          function(pub, total_genes,
                   max_score = Inf,
                   show_progress = TRUE,
                   remove_ambiguous = TRUE,
                   verbose = FALSE,
                   nsim = 100000){
            
            terms_of_interest <- pub@terms_of_interest
            genes_to_sample <- pub@genes
            simulation_of_literature_null <- data.frame(2,2,2)
            simulation_of_literature_null <- simulation_of_literature_null[-1,]
            

            if (length(pub@all_counts) == 0){
             pub@total_genes <- total_genes
             message('Running PubScore for all genes. Might take a while!')
             pb_test_score <-
               progress::progress_bar$new(format = "[:bar] :current/:total (:percent) eta: :eta", total = length(total_genes))
             
            for (i in total_genes){
              pb_test_score$tick()
              
              tryCatch({
                pub_counts <- get_literature_score(i, terms_of_interest, show_progress = FALSE)
                new_line <- data.frame(i, pub_counts)
                simulation_of_literature_null <- rbind(simulation_of_literature_null, new_line)
                Sys.sleep(0.2)}, error = function(e){print(e)
                })
            }
            simulation_of_literature_null <- simulation_of_literature_null[simulation_of_literature_null$i != "",]  
            pub@all_counts <- simulation_of_literature_null[,-1]
            } 
            if (max_score == Inf){
            if (remove_ambiguous == FALSE){
              
              distribution_of_scores <- .getSimulation_test(pub, n_simulations = nsim)
              score <- pub@literature_score
              pvalue <-sum(distribution_of_scores[,1] >= score)/length(distribution_of_scores[,1])
              
              print('The p-value by simulation is:')
              print(pvalue) 
              pub@p_value <- pvalue
              return(pub)
            }
            
            
            if (remove_ambiguous == TRUE){
              ambiguous_terms <- c("PC", "JUN", "IMPACT", "ACHE", "SRI", "SET", "CS", "PROC", 
                                   "MET", "SHE", "CAD", "DDT", "PIGS", "SARS", "REST", "GC", "CP", 
                                   "STAR", "SI", "GAN", "MARS", "SDS", "AGA", "NHS", "CPE", "POR", 
                                   "MAX", "CAT", "LUM", "ANG", "POLE", "CLOCK", "TANK", "ITCH", 
                                   "SDS", "AES", "CIC", "FST", "CAPS", "COPE", "F2", "AFM", "SPR", 
                                   "PALM", "C2", "BAD", "GPI", "CA2", "SMS", "INVS", "WARS", "HP", 
                                   "GAL", "SON", "AFM", "BORA", "MBP", "MAK", "MALL", "COIL", "CAST ")
              
              distribution_of_scores <- .getSimulation_test(pub, ambiguous =  ambiguous_terms, n_simulations = nsim)
              score <- pub@literature_score
              pvalue <-sum(distribution_of_scores[,1] >= score)/length(distribution_of_scores[,1])
              
              print('The p-value by simulation is:')
              print(pvalue) 
              pub@p_value <- pvalue
              return(pub)
            }
            }
            })
pub <- test_score(pub, remove_ambiguous = T)


