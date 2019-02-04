####Simplified Functional Comapctness script 
#########################################
#### Date : 1/30/2019 at 1:15 PM  
library(sp)
library(raster) # raster (pixel) object handling
library(rgdal) # shapefile access
library(rgeos) # geometry operations
library(reshape2)
library(gmapsdistance)
library(foreign)
library(RCurl)
library(XML)
library(fifer)
library(geosphere)
library(doBy)
library(texreg)
################################
##Step 0: Set working directory
setwd("")

##Step 1: Name paths to shapefiles so that they can be read in easily by readOGR
cbg_path <- ""
cbgs <- readOGR(cbg_path, "") # write in the name of the spatial files in the quotation marks 
cbgs <- subset(cbgs, POP2010 > 0) # 216865 rows,  2966 empty rows ; getting rid of rows with -99
zip_path <- ""
zctas <- readOGR(zip_path, "" ) #write in the name of the spatial files in the quotation marks
zctas$GEOID10 <- as.character(zctas$GEOID10) #changing to character from factor 
zip_cents <- readOGR(zip_path, " ") #insert name of zip centroid shapefile 

##Step 2: Computing the CBG centroids and projections 
cbgCents <- gCentroid(cbgs[1,],byid=TRUE)
for(i in 2:nrow(cbgs)){
  tryCatch({
    subcbg <- cbgs[i,]
    tempCent <- gCentroid(subcbg,byid=TRUE)
    cbgCents <- rbind(cbgCents, tempCent)
  }, error=function(e){cat("ERROR :", conditionMessage(e), "/n")}
  )}
saveRDS(cbgCents, "cbgCents.Rdata") # you will want to save this just in case. 
cbgCents <- readRDS("cbgCents.Rdata")
crs.zip<-proj4string(zctas)
cbgCents <- spTransform(cbgCents,crs.zip)
cbgs <- spTransform(cbgs,crs.zip)


##merging on CBG information onto the centroids 
cbgCents$FIPS <- over(cbgCents, cbgs)$FIPS
cbgCents <- merge(cbgCents,cbgs,by="FIPS")
cbgCents$zcta <- over(cbgCents,zctas)$GEOID10

###Step 3: Extracting coordinates and merging on ZCTA info

zip_coords <- coordinates(zip_cents)
zip_coords <- cbind(zip_coords, zip_cents@data)
zip_coords <- zip_coords[, c(1,2,4)]
cbgCents <- merge(cbgCents, zip_coords,by.x="zcta",  by.y="GEOID10")
testdf <- as.data.frame(cbgCents)

saveRDS(cbgCents, "") #should probably save progress here 
##creating legible coordinates for the gmap fxn 
testdf$cbg_coord <- paste(testdf$y,sep="+",testdf$x)
testdf$zip_coord <- paste(testdf$coords.x2,sep="+",testdf$coords.x1)

##Step 4: creating data frame for the ananlysis; insert api
#If you do not have an API yet, go here: 
# https://developers.google.com/maps/documentation/distance-matrix/get-api-key
travel_times_<-matrix(data=NA,nrow=nrow(testdf),ncol=3) # for all data 
t_api <- ""
set.api.key(t_api)

#subset respective states here by using the FIP code 
##subsetting by a single state
ohio_df <- subset(testdf2,STATE_FIPS=="39")
texas_df <- subset(testdf2,STATE_FIPS=="48")

##Step 5: 
##Run the script. Either use the subset state data, or cap out at 20,000 requests 
travel_times_tx<-matrix(data=NA,nrow=nrow(texas_df),ncol=3)
for(i in 1:nrow(travel_times_tx)){
  tryCatch({
    storage.chi <- gmapsdistance(texas_df$zip_coord[i],texas_df$cbg_coord[i],
                                 mode = "driving", key = tyler_api, dep_date ="2020-04-01",
                                 dep_time = "12:00:00")
    travel_times_tx[i,1]<-storage.chi$Time
    travel_times_tx[i,2]<-storage.chi$Distance
    travel_times_tx[i,3]<-storage.chi$Status
  }, error=function(e){cat("ERROR :", conditionMessage(e), "\n")}
  )} 
saveRDS(travel_times_tx, "travel_times_tx.Rdata")
###The euclidean distance comparison 
euc_distance_tx <- matrix(data = NA, nrow = nrow(texas_df),ncol = 1)
for(i in 1:nrow(texas_df)){
  euc_distance_tx[i,1] <- distGeo(c(texas_df$coords.x1[i], texas_df$coords.x2[i]),
                                  c(texas_df$x[i], texas_df$y[i]))
}


###Step 6: reformatting data 
travel_times_txdf <- as.data.frame(travel_times_tx)
colnames(travel_times_txdf)[1] <- "time"
colnames(travel_times_txdf)[2] <- "distance"
colnames(travel_times_txdf)[3] <- "route"
##cbinding on the pop data. 
travel_times_txdf <- cbind(travel_times_txdf, texas_df$zcta, texas_df$POP2010, 
                           texas_df$POP10_SQMI)
colnames(travel_times_txdf)[4] <- "zcta"
colnames(travel_times_txdf)[5] <- "pop2010"
colnames(travel_times_txdf)[6] <- "pop10_sqmi"
travel_times_txdf$pop2010 <- as.numeric(travel_times_txdf$pop2010)
travel_times_txdf$time <- as.numeric(as.character(travel_times_txdf$time))
travel_times_txdf$distance <- as.numeric(as.character(travel_times_txdf$distance))
travel_times_txdf <- cbind(travel_times_txdf, euc_distance_tx)
travel_times_txdf$hours <- travel_times_txdf$time/3600
travel_times_txdf$miles <- travel_times_txdf$distance*0.000621371  
travel_times_txdf$euc_miles <- travel_times_txdf$euc_distance_tx*0.000621371   
travel_times_txdf$distance_diff <- travel_times_txdf$euc_miles - travel_times_txdf$miles
travel_times_txdf$hours_pop_wt <- travel_times_txdf$hours*(travel_times_txdf$pop2010/200)
travel_times_txdf$miles_pop_wt <- travel_times_txdf$miles*(travel_times_txdf$pop2010/200)
travel_times_txdf$ddif_pop_wt <- travel_times_txdf$distance_diff*(travel_times_txdf$pop2010/200)

###Step 7: Collapsing data 
library(doBy)
tx_zip_col <- summaryBy(hours_pop_wt + miles_pop_wt + ddif_pop_wt ~ zcta,
                        FUN = c(sum, mean, median,sd),data = travel_times_txdf) 
hist(tx_zip_col$hours_pop_wt.sum, breaks=200)
tx_zip_col <- subset(tx_zip_col,hours_pop_wt.sum<1000 ) ## Anything above 1000 hours is NA data. Recall that not all portions of the 
#U.S. are in ZIP codes. Therefore, the NA sum is useless 
summary(tx_zip_col$hours.sum) ## summary of the data of interest 
zctas$GEOID10 <- as.character(zctas$GEOID10)
zctas <- merge(zctas, tx_zip_col, by.x="GEOID10",by.y="zcta")
zcta_tx <- zctas[!is.na(zctas$hours_pop_wt.sum),]
quants_zip<-quantile(zcta_tx$hours_pop_wt.sum,seq(0,1,by=.2))


### Plotting out map
###assigning colors and plotting 
color_zip <-c("darkgreen", "darkolivegreen1", "gold", "firebrick1", "firebrick4")
zcta_tx$color[zcta_tx$hours_pop_wt.sum < quants_zip[2]] <- color_zip[1]
zcta_tx$color[zcta_tx$hours_pop_wt.sum >= quants_zip[2] & 
                zcta_tx$hours_pop_wt.sum < quants_zip[3]] <- color_zip[2]
zcta_tx$color[zcta_tx$hours_pop_wt.sum >= quants_zip[3] & 
                zcta_tx$hours_pop_wt.sum < quants_zip[4]] <- color_zip[3]
zcta_tx$color[zcta_tx$hours_pop_wt.sum >= quants_zip[4] & 
                zcta_tx$hours_pop_wt.sum < quants_zip[5]] <- color_zip[4]
zcta_tx$color[zcta_tx$hours_pop_wt.sum >= quants_zip[5] & 
                zcta_tx$hours_pop_wt.sum <= quants_zip[6]] <- color_zip[5]
##plotting 
jpeg("texas_zips_map.jpg", res=300, height = 5, width = 5, units = "in")
par(mar=c(0.6,0.6,0.6,0.6))
par(mfrow=(c(1,1)))
plot(zcta_tx, col=zcta_tx$color, axes=FALSE, main="Texas ZIP Code Functional Compactness")
legend('bottomleft', legend = c('Most Compact', 'Compact', 'Mixed', 
                                'Not-Compact', "Least Compact"  )
       , fill = color_zip, bty = "n", title="ZIP code Preservation", cex=1)
dev.off()

##more plots 

library(stringr)
#zip_pop <- read.csv("zcta_pop.csv")
zip_data <- read.csv("zip_code_population2010.csv")
zip_data$ZCTA5CE10 <- as.character(zip_data$ZCTA5CE10)
zip_data$ZCTA5CE10 <- str_pad(zip_data$ZCTA5CE10, width=5, pad="0", side="left")
#zip_pop$Zip.Code.ZCTA <- as.character(zip_pop$Zip.Code.ZCTA)
#zip_pop$GEOID10 <- str_pad(zip_pop$Zip.Code.ZCTA, width=5, pad="0", side="left")
zcta_tx <- merge(zcta_tx, zip_data, by.x="GEOID10", by.y="ZCTA5CE10")
zcta_tx$log_pop <- log(zcta_tx$POP2010_wtz.sum)
mod <- lm(hours_pop_wt.sum ~log_pop, data=zcta_tx)
par(mar=c(4.5,4.5,4.5,4.5))
jpeg("zip_pop_by_comp.jpg", res=300, height = 5, width = 5, units = "in")
plot(zcta_tx$log_pop,zcta_tx$hours_pop_wt.sum,xlab="Logged Pop.",
     ylab="Cumulative Travel Time (Hours)", 
     main="ZIP Code Functional Compactness by Population")
text(hours_pop_wt.sum ~log_pop, labels=zcta_tx$GEOID10,data=zcta_tx, cex=0.9, font=1)
abline(mod, col="red", lwd=3)
dev.off()

jpeg("zip_fxncomp_hist.jpg", res=300, height = 5, width = 5, units = "in")
hist(zcta_tx$hours_pop_wt.sum,xlab="Cumulative Travel Times (Hours)",
     main="Texas ZIP Code Functional Compactness",breaks=200)

dev.off()

##Example of ZIP code and CBGs 
outliers <- subset(zcta_tx, hours_pop_wt.sum >= 100)
View(outliers@data)
tx_cbgcents <- subset(sub_cbgCents, STATE_FIPS=="48" & zcta=="75098")
cent75098 <- subset(zip_cents, GEOID10=="75098")
##plot example 
jpeg("example_zip.jpg", res=300, height = 5, width = 5, units = "in")
plot(zcta_tx[1,], main="ZIP Code 75098")
points(cent75098, col="red", cex=2,pch=15)
points(tx_cbgcents, pch=3, col="black")
legend('bottomleft', legend = c("ZIP Code Centroid", "CBG Centroid")
       , col=c("red","black"), bty = "n", title="", cex=1, pch=c(15,3))
dev.off()