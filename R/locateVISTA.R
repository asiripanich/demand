suppressPackageStartupMessages(library(haven)) # for spss reading
suppressPackageStartupMessages(library(sf)) # for spatial things
suppressPackageStartupMessages(library(dplyr)) # for manipulating data
suppressPackageStartupMessages(library(ggplot2)) # for plotting data
suppressPackageStartupMessages(library(fitdistrplus)) # for log normal distributions

plotHistograms <- function(dist_vista,dist_demand,mode,binwidth=100) {
  # binwidth=400
  # mode="walk"
  dist_vista=vistaTrips%>%filter(ArrivingMode==mode) %>%
    mutate(Distance=ifelse(Distance<1,1,Distance))
  dist_demand=vpTrips%>%filter(ArrivingMode==mode) %>%
    mutate(Distance=ifelse(Distance<1,1,Distance))
  maxDist <- max(c(dist_vista$Distance,dist_demand$Distance))
  
  dist_vista_aggregated <- dist_vista %>%
    mutate(distance=findInterval(Distance,seq(0,maxDist,binwidth))) %>%
    mutate(distance=distance*binwidth-(binwidth*0.75)) %>%
    group_by(distance) %>%
    summarise(count=sum(weight,na.rm=T)) %>%
    mutate(proportion=count/sum(count,na.rm=T))

  dist_demand_aggregated <- dist_demand %>%
    mutate(distance=findInterval(Distance,seq(0,maxDist,binwidth))) %>%
    mutate(distance=distance*binwidth-(binwidth*0.25)) %>%
    group_by(distance) %>%
    summarise(count=n()) %>%
    mutate(proportion=count/sum(count,na.rm=T))
  

  fit_lnorm1 <- fitdist(dist_vista$Distance,weights=as.integer(dist_vista$weight), distr="lnorm")
  fit_coef1 <- fit_lnorm1$estimate
  cat(paste0(" VISTA: mean=",fit_coef1[1],", sd=",fit_coef1[2],"\n"))
  
  fit_lnorm2 <- fitdist(dist_demand$Distance, distr="lnorm")
  fit_coef2 <- fit_lnorm2$estimate
  cat(paste0("Demand: mean=",fit_coef2[1],", sd=",fit_coef2[2],"\n"))
  
  
  
  g <- ggplot(dist_vista_aggregated,
              aes(x=distance,y=proportion)) +
    geom_col(width=binwidth*0.5,position=position_nudge(x=0),fill="#1f78b4") + # light blue
    geom_col(data=dist_demand_aggregated,width=binwidth*0.5,
             position=position_nudge(x=0),fill="#33a02c") + # light green
    stat_function(fun=function(x) dlnorm(x, meanlog=fit_coef1[1],
                                         sdlog=fit_coef1[2]) * binwidth,
                  color="#a6cee3", size=1, xlim=c(0,maxDist)) + # dark blue
    stat_function(fun=function(x) dlnorm(x, meanlog=fit_coef2[1],
                                         sdlog=fit_coef2[2]) * binwidth,
                  color="#b2df8a", size=1, xlim=c(0,maxDist)) + # dark green
    labs(x = "Distance traveled", y="Proportion") +
    scale_y_continuous(labels = scales::percent)
  return(g)
}



# Just need the non-spatial data from the Meshblocks
MB_2016_AUST <- st_read("../data/absRegionsReprojected.sqlite",layer="MB_2016_AUST") %>%
  st_drop_geometry() %>%
  mutate(mb_code_2016 = as.numeric(as.character(mb_code_2016)),
         sa1_maincode_2016 = as.numeric(as.character(sa1_maincode_2016)),
         sa2_maincode_2016 = as.numeric(as.character(sa2_maincode_2016)),
         sa3_code_2016 = as.numeric(as.character(sa3_code_2016))
  ) %>%
  dplyr::select(mb_code_2016,sa1_maincode_2016,sa2_maincode_2016,sa3_code_2016)

sa1_maincode_2016 <- MB_2016_AUST %>%
  dplyr::select(sa1_maincode_2016,sa2_maincode_2016,sa3_code_2016) %>%
  distinct()

# MUST HAVE PERMISSION TO ACCESS THIS DATASET, IT IS NOT PUBLICALLY AVAILABLE
vistaTrips <- read_sav("../VISTA/RMIT VISTA 2012-16 Pack/T_VISTA12_16_v1.sav") %>%
  # Need to have valid coordinates for origin and destination
  filter(ORIGLONG != 2 & ORIGLAT != -2 & DESTLONG != -1 & DESTLAT != -1) %>%
  # Only want weekdays
  filter(TRAVDOW %in% 1:5) %>%
  # Only want trips within the study region  
  filter(ORIGMESHBLOCK %in% MB_2016_AUST$mb_code_2016 &
           DESTMESHBLOCK %in% MB_2016_AUST$mb_code_2016) %>%
  mutate(mb_code_2016=as.numeric(ORIGMESHBLOCK)) %>%
  # convert ditance to metres
  mutate(Distance=as.integer(round(CUMDIST*1000))) %>%
  # 1,2,3,6 = car; 4 = walk; 5 = bike; 7,8,9,10 = pt
  mutate(ArrivingMode = ifelse(LINKMODE %in% c(7,8,9,10), "pt",NA),
         ArrivingMode = ifelse(LINKMODE %in% c(1,2,3,6), "car",ArrivingMode),
         ArrivingMode = ifelse(LINKMODE %in% c(5), "bike",ArrivingMode),
         ArrivingMode = ifelse(LINKMODE %in% c(4), "walk",ArrivingMode)) %>%
  filter(!is.na(ArrivingMode)) %>%
  dplyr::select(mb_code_2016,ArrivingMode,Distance,weight=CW_WDTRIPWGT_SA3)

# need SA1, SA2, SA3 ids
vistaTrips <- inner_join(MB_2016_AUST,vistaTrips, by="mb_code_2016") %>%
  dplyr::select(sa1_maincode_2016,sa2_maincode_2016,sa3_code_2016,ArrivingMode,Distance,weight)


# trips generated by the virtual population
vpTrips <- read.csv("../output/5.locate/plan.csv") %>%
  filter(!is.na(ArrivingMode)) %>%
  dplyr::select(sa1_maincode_2016=SA1_MAINCODE_2016,ArrivingMode,Distance) %>%
  inner_join(sa1_maincode_2016,by="sa1_maincode_2016") %>%
  dplyr::select(sa1_maincode_2016,sa2_maincode_2016,sa3_code_2016,ArrivingMode,Distance)
  


plotHistograms(vistaTrips,vpTrips,"walk",binwidth=400)+xlim(0,5000)
ggsave("../output/5.locate/analysis-walk.pdf",width=8,height=5)

plotHistograms(vistaTrips,vpTrips,"bike",binwidth=1000)+xlim(0,20000)
ggsave("../output/5.locate/analysis-bike.pdf",width=8,height=5)

plotHistograms(vistaTrips,vpTrips,"pt",binwidth=2000)+xlim(0,60000)
ggsave("../output/5.locate/analysis-pt.pdf",width=8,height=5)

plotHistograms(vistaTrips,vpTrips,"car",binwidth=2000)+xlim(0,60000)
ggsave("../output/5.locate/analysis-car.pdf",width=8,height=5)






# Summarise at SA1 level
vistaTripsSA1 <- vistaTrips %>%
  group_by(sa1_maincode_2016,ArrivingMode) %>%
  summarise(meanExpected=mean(Distance,na.rm=TRUE),
            sdExpected=sd(Distance,na.rm=TRUE),
            countVista=n()) %>%
  ungroup()
vpTripsSA1 <- vpTrips %>%
  group_by(sa1_maincode_2016,ArrivingMode) %>%
  summarise(meanActual=mean(Distance,na.rm=TRUE),
            sdActual=sd(Distance,na.rm=TRUE),
            countVP=n()) %>%
  ungroup()
expectedVsActualSA1 <- inner_join(vistaTripsSA1,vpTripsSA1,by=c("sa1_maincode_2016","ArrivingMode"))
ggplot(expectedVsActualSA1, aes(x=meanExpected,y=meanActual)) +
  geom_point(aes(color=countVP),size=0.5) +
  scale_colour_gradient(low="#7bccc4", high="#084081") +
  geom_abline(aes(slope = 1, intercept=0),size=0.2) +
  facet_wrap(~ArrivingMode, scales="free", ncol=2) +
  labs(x="Expected (VISTA) mean distance", y="Actual (VP) mean distance") + 
  ggtitle('Expected versus actual mean distances by SA1 region') +
  ggsave("../output/5.locate/analysis-expected-versus-actual-mean-distances-SA1.pdf", width=210, height=160, units = "mm")


# Summarise at SA2 level
vistaTripsSA2 <- vistaTrips %>%
  group_by(sa2_maincode_2016,ArrivingMode) %>%
  summarise(meanExpected=mean(Distance,na.rm=TRUE),
            sdExpected=sd(Distance,na.rm=TRUE),
            countVista=n()) %>%
  ungroup() %>%
  filter(countVista>2)
vpTripsSA2 <- vpTrips %>%
  group_by(sa2_maincode_2016,ArrivingMode) %>%
  summarise(meanActual=mean(Distance,na.rm=TRUE),
            sdActual=sd(Distance,na.rm=TRUE),
            countVP=n()) %>%
  ungroup()
expectedVsActual <- inner_join(vistaTripsSA2,vpTripsSA2,by=c("sa2_maincode_2016","ArrivingMode"))
ggplot(expectedVsActual, aes(x=meanExpected,y=meanActual)) +
  geom_point(aes(color=countVP),size=0.5) +
  scale_colour_gradient(low="#7bccc4", high="#084081") +
  geom_abline(aes(slope = 1, intercept=0),size=0.2) +
  facet_wrap(~ArrivingMode, scales="free", ncol=2) +
  labs(x="Expected (VISTA) mean distance", y="Actual (VP) mean distance") + 
  ggtitle('Expected versus actual mean distances by SA2 region') +
  ggsave("../output/5.locate/analysis-expected-versus-actual-mean-distances-SA2.pdf", width=210, height=160, units = "mm")


# Summarise at SA3 level
vistaTripsSA3 <- vistaTrips %>%
  group_by(sa3_code_2016,ArrivingMode) %>%
  summarise(meanExpected=mean(Distance,na.rm=TRUE),
            sdExpected=sd(Distance,na.rm=TRUE),
            countVista=n()) %>%
  ungroup()
vpTripsSA3 <- vpTrips %>%
  group_by(sa3_code_2016,ArrivingMode) %>%
  summarise(meanActual=mean(Distance,na.rm=TRUE),
            sdActual=sd(Distance,na.rm=TRUE),
            countVP=n()) %>%
  ungroup()
expectedVsActualSA3 <- inner_join(vistaTripsSA3,vpTripsSA3,by=c("sa3_code_2016","ArrivingMode"))
ggplot(expectedVsActualSA3, aes(x=meanExpected,y=meanActual)) +
  geom_point(aes(color=countVP),size=0.5) +
  scale_colour_gradient(low="#7bccc4", high="#084081") +
  geom_abline(aes(slope = 1, intercept=0),size=0.2) +
  facet_wrap(~ArrivingMode, scales="free", ncol=2) +
  labs(x="Expected (VISTA) mean distance", y="Actual (VP) mean distance") + 
  ggtitle('Expected versus actual mean distances by SA3 region') +
  ggsave("../output/5.locate/analysis-expected-versus-actual-mean-distances-SA3.pdf", width=210, height=160, units = "mm")


maxDist=max(distanceMatrix)
binwidth=500
distanceMatrixAggregated <- data.frame(Distance=as.vector(distanceMatrix)) %>%
  mutate(distance=findInterval(Distance,seq(0,maxDist,binwidth))) %>%
  mutate(distance=distance*binwidth-(binwidth*0.5)) %>%
  group_by(distance) %>%
  summarise(count=n())

ggplot(distanceMatrixAggregated,
       aes(x=distance,y=count)) +
  geom_col(width=binwidth,position=position_nudge(x=0),fill="gray5") +
  labs(x = "Distance traveled", y="count") +
  xlim(0,60000)
ggsave("../output/5.locate/sa1_distanceDistribution.pdf",width=8,height=5)

