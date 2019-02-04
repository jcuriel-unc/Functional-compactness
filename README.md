# Functional-compactness Project
#  Goal
This project and script are developed to calculate the functional compactness of geographic units. Functional compactness is defined as a unit of geography that minimizes the travel times between a geographic unit's centroid and the residents. Unlike euclidean distance, the script takes into account transportation infrastructure, which deviates from straight up euclidean distance. The script therefore permits the user an accurate estimation of the ease in which one can reach all of the residents of an area from the centroid of the unit of geography. 

In order to use the script, please acquire a Google Distance API. 

https://developers.google.com/maps/documentation/distance-matrix/get-api-key

Upon acquiring the API, also download the ZCTA and Census Block Group shapefiles from the U.S. Census: 

https://www.census.gov/cgi-bin/geo/shapefiles/index.php

After downloading these data, the script will compute the geographic centroids of the Census Block Groups (CBG), overlay them with their respective ZIP codes, extract coordinates, and then run a loop of the coordinates in order to calculate cumulative travel times. The script weights the travel times between the ZIP code centroid and the CBG centroids by the population of a CBG divided by 200. It is possible to randomly generate points within a CBG and run the script with these random coordinates, though the time and expenses make it a poor idea.  

Please note that with the google API, one should receive 20,000 free requests. Therefore, it is strongly recommended to run no more than 20,000 requests a day in order to minimize costs. Given the 214,000 CBGs within the U.S., this should allow the user to compute the functional compactness for all ZIP codes in 10 days if one souught to not spend any money. Note that the Google API can process at least 2 requests per second when deciding as to how much data that you would like to process in one sitting. 

![example_zip](https://user-images.githubusercontent.com/47302709/52214916-e1b1ad00-2860-11e9-84b7-081d929d3fd0.jpg)


![zip_fxncomp_hist](https://user-images.githubusercontent.com/47302709/52180942-0141ca80-27ba-11e9-856e-d6e5fbd141a6.jpg)


##Texas ZIP Code Functional Compactness
![texas_zips_map](https://user-images.githubusercontent.com/47302709/52180834-00f4ff80-27b9-11e9-84e9-853bf08c3d49.jpg)

##Distribution of ZIP Code Functional Compactness by Logged Population
![zip_pop_by_comp](https://user-images.githubusercontent.com/47302709/52180856-34378e80-27b9-11e9-9949-13f20eb3038d.jpg)

