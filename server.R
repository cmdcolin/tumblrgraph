library(shiny)
library(Rgraphviz)
library(stringr)
library(RBGL)
library(animation)





# Define server logic for random distribution application
shinyServer(function(input, output) {
  
  # Reactive expression to generate the requested distribution. This is 
  # called whenever the inputs change. The output renderers defined 
  # below then all used the value computed from this expression
  
  
  output$myanimation<-renderUI({
    
    # create tmp directory without using tempdir()
    wordspace<-c(0:9, letters, LETTERS)
    randstr<-paste(sample(wordspace,size=6, replace=TRUE),collapse="")
    myoutdir<-file.path('tmp',randstr)
    dir.create(file.path('www',myoutdir),recursive=TRUE)
    
    if(input$animationtype=='html'){ 
      saveHTML({
        compileGraph()
      }, img.name = "anim_plot", imgdir = "img", autobrowse = FALSE, 
         htmlfile='animation.html',outdir=file.path('www',myoutdir))
      
      
      tags$div(tags$iframe(src=file.path(myoutdir,'animation.html'), 
                           style="width:1024px;height:768px;"))
    } else if(input$animationtype=="gif") {
      saveGIF({
        compileGraph()
      }, movie.name = "animation.gif", autobrowse = FALSE, clean=FALSE,outdir=file.path('www',myoutdir))
      
      tags$div(tags$p(file.path(myoutdir,'animation.gif')),tags$br(),tags$img(src=file.path(myoutdir,'animation.gif')))
    } else if(input$animationtype=="static") {
      png(file=file.path(file.path('www',myoutdir),"graph.png"),width=1024,height=768)
      staticGraph()
      dev.off()
      tags$div(tags$img(src=file.path(myoutdir,'graph.png')))
    }
    
  })
  
  
  
  compileGraph<-function() {
    myfile<-strsplit(input$users,'\n')
    
    reblogSet<-str_match(myfile[[1]],"([^ ]*) reblogged this from ([^ ]*)")
    whoposted<-str_match(myfile[[1]],"([^ ]*) posted this")
    
    #remove non-reblog lines
    reblogSet<-reblogSet[!is.na(reblogSet[,1]),]
    whoposted<-whoposted[!is.na(whoposted[,1]),]
    
    nr<-nrow(reblogSet)
    for (i in 2:nrow(reblogSet)) {
      plotSubset(reblogSet, whoposted, i)
    }
  }
  
  staticGraph<-function() {
    myfile<-strsplit(input$users,'\n')
    reblogSet<-str_match(myfile[[1]],"([^ ]*) reblogged this from ([^ ]*)")
    whoposted<-str_match(myfile[[1]],"([^ ]*) posted this")
    
    #remove non-reblog lines
    reblogSet<-reblogSet[!is.na(reblogSet[,1]),]
    whoposted<-whoposted[!is.na(whoposted[,1]),]
    
    nr<-nrow(reblogSet)
    plotSubset(reblogSet, whoposted, nr)
  }
  
  plotSubset<-function(reblogSet, whoposted,i) {
    # grep 
    nr<-nrow(reblogSet)
    allBlogs<-unique(c(reblogSet[(nr-i):nr,2],reblogSet[(nr-i):nr,3]))
    rEG <- new("graphNEL", nodes=allBlogs, edgemode="directed")
    apply(reblogSet[(nr-i):nr,],1,function(row) {
      rEG<<-addEdge(row[3],row[2],rEG,1)
    })
    attrs <- list(node=list(shape="ellipse", fixedsize=FALSE,overlap=FALSE))
    mydistances<-sp.between(rEG,whoposted[2],nodes(rEG),detail=FALSE)
    
    mydistances<-as.vector(unlist(mydistances))
    mydistances[is.na(mydistances)]=0
    
    nA=list()
    nNodes <- length(nodes(rEG))
    nA$fontsize <- rep(12, nNodes)
    
    if(input$colortype=="distance") {
      ncol=max(mydistances)+3
      nA$fillcolor=(mydistances)+1
    } else if(input$colortype=="degree") {
      ncol=max(degree(rEG)$outDegree)+3
      nA$fillcolor=(degree(rEG)$outDegree)+1
    }
    
    #add parameters for sizenode
    if(!is.null(input$sizenode)&&input$sizenode==TRUE) {
      #scale on node degree
      degreescale=sqrt((degree(rEG)$outDegree)/max(degree(rEG)$outDegree+1))
      #additionally scale on size of ndoe name
      widthscale=2*sapply(nodes(rEG),nchar)/max(sapply(nodes(rEG),nchar))
      #input scalefactor
      scalefactor=as.numeric(input$scalefactor)
      
      #change width,height,fontsize using scalefactors
      nA$width=0.5*3*scalefactor*degreescale+widthscale
      nA$height=0.15*5*scalefactor*degreescale
      nA$fontsize=10*scalefactor*degreescale+12
    }

    
    nA <- lapply(nA, function(x) { names(x) <- nodes(rEG); x})
    #plot(z, nodeAttrs=nA,attrs=attrs)
    
    mypal<-switch(input$palettetype,rainbow=rainbow(ncol),
                  topo.colors=topo.colors(ncol),
                  terrain.colors=terrain.colors(ncol),
                  heat.colors=heat.colors(ncol),
                  cm.colors=cm.colors(ncol))
    palette(mypal)
    mygraph <- layoutGraph(rEG,nodeAttrs=nA, layoutType=input$graphtype,attrs=attrs)
    
    #this is required to add the node attributes for fontsize
    #see https://stat.ethz.ch/pipermail/bioconductor/2008-January/021031.html
    nodeRenderInfo(mygraph) <- list(fontsize = nA$fontsize)
    renderGraph(mygraph,graph.pars=list(overlap=FALSE))
  }

  
  
})

