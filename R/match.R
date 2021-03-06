# Matches ABS census-like persons to VISTA-like plans
matchPersons<-function(censuscsv, vistacsv, outcsv) {
  
  # Read in the persons
  gz1<-gzfile(censuscsv, 'rt')
  echo(paste0('Loading ABS census-like persons from ', censuscsv, '\n'))
  persons<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  # Read in the plans
  gz1<-gzfile(vistacsv, 'rt')
  echo(paste0('Loading VISTA-like plans from ', vistacsv, '\n'))
  plans<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  # TODO: to be replaced with demographics based matching
  echo(paste0('Matching census-like persons to VISTA-like plans\n'))
  size<-min(length(unique(persons$AgentId)), length(unique(plans$PlanId)))
  personIds<-unique(persons$AgentId)[1:size]
  planIds<-unique(plans$PlanId)[1:size]
  match<-data.frame(PlanId=planIds, AgentId=personIds)
  gz1<-gzfile(outcsv, 'wt')
  write.table(match, file=gz1, append=FALSE, row.names=FALSE, sep = ',')
  close(gz1)
  echo(paste0('Wrote ', outcsv, '\n'))
}
