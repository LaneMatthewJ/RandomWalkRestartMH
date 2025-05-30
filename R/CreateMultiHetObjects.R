## R Code for the Random Walk with Restart Package (RandomWalkRestartMH).

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Functions to create Multiplex and Multiplex-Heterogeneous objects.
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

## Roxy Documentation comments
#' Create multiplex graphs from individual networks
#'
#' \code{create.multiplex} is a function to create a multiplex network
#' (\code{Multiplex} object) from a list of individual networks defined as
#' \code{igraph} objects. See more details about multiplex networks below.
#' If just one network is provided, a Multiplex object with one layer is
#' therefore created (A monoplex network).
#'
#' @usage create.multiplex(...)
#'
#' @details A multiplex network is a collection of layers (monoplex networks)
#' sharing the same nodes, but in which the edges represent relationships of
#' different nature. At least a list with one element, an igraph object, should
#' be provided. 
#'
#' @param LayersList A list containing igraph objects describing monoplex 
#' networks in every element. We recommend to give names to the different 
#' networks (igraph objects). 
#' @param ... Further arguments passed to \code{create.multiplex}
#'
#' @return A Multiplex object. It contains a list of the different graphs
#' integrating the multiplex network, the names and number of its nodes and the
#' number of layers.
#'
#' @seealso \code{\link{create.multiplexHet},\link{isMultiplex}}
#'
#' @author Alberto Valdeolivas Urbelz \email{alvaldeolivas@@gmail.com}
#'
#' @examples
#' m1 <- igraph::graph(c(1,2,1,3,2,3), directed = FALSE)
#' m2 <- igraph::graph(c(1,3,2,3,3,4,1,4), directed = FALSE)
#' multiObject <- create.multiplex(list(m1=m1,m2=m2))
#'
#'@import igraph
#'@rdname create.multiplex
#'@export
create.multiplex <- function(...){
    UseMethod("create.multiplex")
}

#' @import foreach
#' @import parallel
#' @import doParallel
#' @rdname create.multiplex
#' @export
create.multiplex.default <- function(LayersList,...){
        
    if (!class(LayersList) == "list"){
        stop("The input object should be a list of graphs.")
    }
    
    
    Number_of_Layers <- length(LayersList)
    SeqLayers <- seq(Number_of_Layers)
    Layers_Name <- names(LayersList)
        
    if (!all(sapply(SeqLayers, function(x) is.igraph(LayersList[[x]])))){
        stop("Not igraph objects")
    }
    
	start_layer_list_time <- Sys.time()
    Layer_List <- lapply(SeqLayers, function (x) {
        if (is.null(V(LayersList[[x]])$name)){
            LayersList[[x]] <- 
                set_vertex_attr(LayersList[[x]],"name", 
                    value=seq(1,vcount(LayersList[[x]]),by=1))
        } else {
            LayersList[[x]]
        }
    })
 #   print(paste("Layers list took: ", Sys.time() - start_layer_list_time))
    
	## We simplify the layers 
    simplify_layers_time_start <- Sys.time()
	# Layer_List <- 
    #     lapply(SeqLayers, function(x) simplify.layers(Layer_List[[x]]))
	numCores <- detectCores()
	registerDoParallel(cores=numCores)
	Layer_List <- foreach(x = SeqLayers) %dopar% {
 		 simplify.layers(Layer_List[[x]])
	}
	stopImplicitCluster()
#	print(paste("Simplfy layers took: ", Sys.time() - simplify_layers_time_start))
	


    ## We set the names of the layers. 
    
    if (is.null(Layers_Name)){
        names(Layer_List) <- paste0("Layer_", SeqLayers)
    } else {
        names(Layer_List) <- Layers_Name
    }
    
    ## We get a pool of nodes (Nodes in any of the layers.)
    Pool_of_Nodes <- 
        sort(unique(unlist(lapply(SeqLayers, 
            function(x) V(Layer_List[[x]])$name))))
        
    Number_of_Nodes <- length(Pool_of_Nodes)
    add_missing_nodes_time <- Sys.time()

    Layer_List <-
        lapply(Layer_List, add.missing.nodes,Number_of_Layers,Pool_of_Nodes)
#	print(paste("add missing nodes took: ", Sys.time() - add_missing_nodes_time))

    # We set the attributes of the layer
    counter <- 0 
    Layer_List <- lapply(Layer_List, function(x) { 
        counter <<- counter + 1; 
        set_edge_attr(x,"type",E(x), value = names(Layer_List)[counter])
    })
    
    MultiplexObject <- c(Layer_List,list(Pool_of_Nodes=Pool_of_Nodes,
        Number_of_Nodes_Multiplex=Number_of_Nodes, 
        Number_of_Layers=Number_of_Layers))
	
    class(MultiplexObject) <- "Multiplex"
    return(MultiplexObject)
}
    
#' @method print Multiplex
#' @export
print.Multiplex <- function(x,...)
{
    cat("Number of Layers:\n")
    print(x$Number_of_Layers)
    cat("\nNumber of Nodes:\n")
    print(x$Number_of_Nodes)
    for (i in seq_len(x$Number_of_Layers)){
        cat("\n")
        print(x[[i]])
    }
}

## Roxy Documentation comments
#' Create multiplex heterogeneous graphs from individual networks
#'
#' \code{create.multiplexHet} is a function to create a multiplex
#' and heterogeneous network (\code{MultiplexHet} object). It combines a
#' multiplex network composed from 1 (monoplex case) up to 6 layers with another
#' single network whose nodes are of different nature. See more details below.
#'
#' @usage create.multiplexHet(...)
#'
#' @details A multiplex network is a collection of layers (monoplex networks)
#' sharing the same nodes, but in which the edges represent relationships of
#' different nature. A heterogeneous network is composed of two single networks
#' where the nodes are of different nature. These nodes of different nature
#' are linked through bipartite interactions.
#'
#' @param Multiplex_object_1 First Multiplex network (\code{Multiplex} object)
#' generated by the function \code{create.multiplex}. This multiplex network
#' will be integrated as the first network of the heterogeneous network.
#' @param Multiplex_object_2 Second Multiplex network (\code{Multiplex} object)
#' generated by the function \code{create.multiplex}. This multiplex network
#' will be integrated as the first network of the heterogeneous network.
#' @param Nodes_relations A data frame containing the relationships (bipartite
#' interactions) between the nodes of the first multiplex network and the nodes 
#' of the second multiplex of the heterogeneous system. The data frame should 
#' contain two or three columns: the first one with the nodes of the multiplex 
#' network; the second one with the nodes of the second network. 
#' The third one is not mandatory and it should contain the weights. Every node 
#' should be present in their corresponding multiplex network.
#' @param ... Further arguments passed to \code{create.multiplexHet}
#'
#' @return A Multiplex Heterogeneous object. It contains a list of the different
#' graphs integrating the multiplex network, the names and number of its nodes
#' and the number of layers. In addition, it contains the graph of the second
#' network integrating the heterogeneous network along with its number of
#' nodes Finally, it contains a expanded bipartite adjacency matrix
#' describing the relations of the nodes in every layer of the multiplex network
#' with the nodes of the second network.
#'
#' @seealso \code{\link{create.multiplex},\link{isMultiplexHet}}
#'
#' @author Alberto Valdeolivas Urbelz \email{alvaldeolivas@@gmail.com}
#'
#' @examples
#' m1 <- igraph::graph(c(1,2,1,3,2,3), directed = FALSE)
#' m2 <- igraph::graph(c(1,3,2,3,3,4,1,4), directed = FALSE)
#' multiObject_1 <- create.multiplex(list(m1=m1,m2=m2))
#' h1 <- igraph::graph(c("A","C","B","E","E","D","E","C"), directed = FALSE)
#' bipartite_relations <- data.frame(m=c(1,3),h=c("A","E"))
#' multiObject_2 <- create.multiplex(list(h1=h1))
#' create.multiplexHet(multiObject_1, multiObject_2,bipartite_relations)
#'
#'@import igraph
#'@import Matrix
#'@rdname create.multiplexHet
#'@export
create.multiplexHet <- function(...) {
    UseMethod("create.multiplexHet")
}

#'@rdname create.multiplexHet
#'@export
create.multiplexHet.default <- function(Multiplex_object_1, Multiplex_object_2,
    Nodes_relations,...)
{
    
    ## We check that all the arguments are correct
    message("checking input arguments...")
    if (!isMultiplex(Multiplex_object_1)) {
        stop("First element should be a multiplex object")
    }
    
    
    if (!isMultiplex(Multiplex_object_2)) {
        stop("Second element should be a multiplex object")
    }
    
    all_nodes1 <- Multiplex_object_1$Pool_of_Nodes
    all_nodes2 <- Multiplex_object_2$Pool_of_Nodes
    
    if (!is.data.frame(Nodes_relations)) {
        stop("Third element should be a data frame")
    } else {
        if (!(ncol(Nodes_relations) %in% c(2,3))) {
            stop("The data frame should contain two or three columns")
        } else {
            if (nrow(Nodes_relations) == 0) {
                stop("The data frame should contain any bipartite interaction")
            } else {
                names_1 <- unique(c(as.character(Nodes_relations[, 1])))
                names_2 <- unique(c(as.character(Nodes_relations[, 2])))
                if (!all(names_1 %in% all_nodes1)){
                    stop("Some of the nodes in the first column of the data
                        frame are not present on the first multiplex network")
                } else {
                    if (!all(names_2 %in% all_nodes2)){
                        stop("Some of the nodes in the second column of the data
                            frame are not present on the second mutilplex 
                            network")
                    }
                }
                ## Now we take care of the weights. 
                if (ncol(Nodes_relations) == 3){
                    b <- 1
                    weigths_bipartite <- as.numeric(Nodes_relations[, 3])
                    if (min(weigths_bipartite) != max(weigths_bipartite)){
                        a <- min(weigths_bipartite)/max(weigths_bipartite)
                        range01 <- 
                            (b-a)*(weigths_bipartite-min(weigths_bipartite))/
                            (max(weigths_bipartite)-min(weigths_bipartite)) + a
                        Nodes_relations[, 3] <- range01
                    } else {
                        Nodes_relations[, 3] <- 
                            rep(1, length(Nodes_relations[, 3]))
                    }
                } else {
                    Nodes_relations$weight <- 
                        rep(1, nrow(Nodes_relations))
                }
            }
        }
    }

    ## Multiplex graph
    Nodes_Multiplex_1 <- Multiplex_object_1$Pool_of_Nodes
    Nodes_Multiplex_2 <- Multiplex_object_2$Pool_of_Nodes
    
    ## Multiplex graph features
    Number_Nodes_1 <- Multiplex_object_1$Number_of_Nodes
    Number_Layers_1 <- Multiplex_object_1$Number_of_Layers
    
    Number_Nodes_2 <- Multiplex_object_2$Number_of_Nodes
    Number_Layers_2 <- Multiplex_object_2$Number_of_Layers
    
    message("Generating bipartite matrix...")
    Bipartite_Matrix <- get.bipartite.graph(Nodes_Multiplex_1, 
        Nodes_Multiplex_2,Nodes_relations, Number_Nodes_1, Number_Nodes_2)
    
    message("Expanding bipartite matrix to fit the multiplex network...")
    Supra_Bipartite_Matrix <- 
        expand.bipartite.graph(Number_Nodes_1,Number_Layers_1,Number_Nodes_2,
            Number_Layers_2, Bipartite_Matrix)

    Multiplex_HetObject <- 
        list(Multiplex1 = Multiplex_object_1, Multiplex2 = Multiplex_object_2,
            BipartiteNetwork = Supra_Bipartite_Matrix)
    
    class(Multiplex_HetObject) <- "MultiplexHet"
    return(Multiplex_HetObject)
    
}

#' @method print MultiplexHet
#' @export
print.MultiplexHet <- function(x,...)
{
    
    cat("Number of Layers Multiplex 1:\n")
    print(x$Multiplex1$Number_of_Layers)
    cat("\nNumber of Nodes Multiplex 1:\n")
    print(x$Multiplex1$Number_of_Nodes_Multiplex)    
    
    for (i in seq_len(x$Multiplex1$Number_of_Layers)){
        cat("\n")
        print(x$Multiplex1[[i]])
    }
    
    cat("\nNumber of Layers Multiplex 2:\n")
    print(x$Multiplex2$Number_of_Layers)
    cat("\nNumber of Nodes Multiplex 2:\n")
    print(x$Multiplex2$Number_of_Nodes_Multiplex)
    
    for (i in seq_len(x$Multiplex2$Number_of_Layers)){
        cat("\n")
        print(x$Multiplex2[[i]])
    }
}
