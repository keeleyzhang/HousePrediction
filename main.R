library(ggplot2)
library(fpp2)
library(dplyr)
library(tbl2xts)
library(stringr)
library(scales) # plotting $$
library(e1071) # skewness
library(corrplot) # correlation plot
library(fastDummies)

# Load the training and test sets
training_data <- read.csv('/Users/nolwenbrosson/Desktop/Cours Nolwen/Cours ESSEC/Big Data Analytics/Group Project/House prediction/all/train.csv', stringsAsFactors = FALSE)
test_data <- read.csv('/Users/nolwenbrosson/Desktop/Cours Nolwen/Cours ESSEC/Big Data Analytics/Group Project/House prediction/all/test.csv', stringsAsFactors = FALSE)

# Merge the two sets into a single one : Full for easier data cleaning
# We also remove 'Id' and 'SalePrice' columns
df.fulldata <- rbind(within(training_data, rm('Id','SalePrice')), within(test_data, rm('Id')))
dim(df.fulldata)

# First, we will check for NA values and have a look at the columns with the most NA values
na.cols <- which(colSums(is.na(df.fulldata)) > 0)
sort(colSums(sapply(df.fulldata[na.cols], is.na)), decreasing = TRUE)

# We see that the Pool Quality columns has the most NA values. 
# We can guess that this corresponds to houses that don't actually have a pool
# To make sure, we will check if some of these houses have a Pool size > 0 
df.fulldata[(df.fulldata$PoolArea > 0) & is.na(df.fulldata$PoolQC),c('PoolQC','PoolArea')]

# For these ones, we will look for the mean of similar sized pools and replace by these values
df.fulldata[,c('PoolQC','PoolArea')] %>%
  group_by(PoolQC) %>%
  summarise(mean = mean(PoolArea), counts = n())

df.fulldata[2421,'PoolQC'] = 'Ex'
df.fulldata[2504,'PoolQC'] = 'Ex'
df.fulldata[2600,'PoolQC'] = 'Fa'

# Also replace all other NA values by 'None' since there is no pool
df.fulldata$PoolQC[is.na(df.fulldata$PoolQC)] = 'None'

# Dealing with the Garage columns. 
# First we check if most garages were built the same year as the house.
length(which(df.fulldata$GarageYrBlt == df.fulldata$YearBuilt))

# Since it appears to be true, we assume all garage were built the same year as the houses.
idx <- which(is.na(df.fulldata$GarageYrBlt))
df.fulldata[idx, 'GarageYrBlt'] <- df.fulldata[idx, 'YearBuilt']

# On our 6 remaining garage cols, we will check if some houses have no garage at all. 
garage.cols <- c('GarageArea', 'GarageCars', 'GarageQual', 'GarageFinish', 'GarageCond', 'GarageType')
df.fulldata[is.na(df.fulldata$GarageCond),garage.cols]

# For the houses that don't have a garage, we set columns to 'None", for others, we replace with mean values
idx <- which(((df.fulldata$GarageArea < 370) & (df.fulldata$GarageArea > 350)) & (df.fulldata$GarageCars == 1))
names(sapply(df.fulldata[idx, garage.cols], function(x) sort(table(x), decreasing=TRUE)[1]))

df.fulldata[2127,'GarageQual'] = 'TA'
df.fulldata[2127, 'GarageFinish'] = 'Unf'
df.fulldata[2127, 'GarageCond'] = 'TA'

# Now we replace all columns of houses with no garage by 0 or 'None'
for (col in garage.cols){
  if (sapply(df.fulldata[col], is.numeric) == TRUE){
    df.fulldata[sapply(df.fulldata[col], is.na), col] = 0
  }
  else{
    df.fulldata[sapply(df.fulldata[col], is.na), col] = 'None'
  }
}

# For the Kitchen Quality and Electrical system (1 missing value), we will look for the most common values and replace Na by them
plot.categoric('KitchenQual', df.fulldata)
df.fulldata$KitchenQual[is.na(df.fulldata$KitchenQual)] = 'TA'

plot.categoric('Electrical', df.fulldata)
df.fulldata$Electrical[is.na(df.fulldata$Electrical)] = 'SBrkr'

# For the 11 Basement features, first let's take a look at them
bsmt.cols <- names(df.fulldata)[sapply(names(df.fulldata), function(x) str_detect(x, 'Bsmt'))]
df.fulldata[is.na(df.fulldata$BsmtExposure),bsmt.cols]

# Since most of the Na values correspond to houses with 0 on each features corresponding to area
# we will fill these values with 'None'. For the other three, we will replace by most common value 'No'. 
plot.categoric('BsmtExposure', df.fulldata)
df.fulldata[c(949, 1488, 2349), 'BsmtExposure'] = 'No'

for (col in bsmt.cols){
  if (sapply(df.fulldata[col], is.numeric) == TRUE){
    df.fulldata[sapply(df.fulldata[col], is.na),col] = 0
  }
  else{
    df.fulldata[sapply(df.fulldata[col],is.na),col] = 'None'
  }
}

# For the Exterior1St and Exterior2nd, there is just one NA value each corresponding to the same house.
# Since we can't really guess, we will set it to 'Other'
df.fulldata$Exterior1st[is.na(df.fulldata$Exterior1st)] = 'Other'
df.fulldata$Exterior2nd[is.na(df.fulldata$Exterior2nd)] = 'Other'

# SaleType, Functional and Utilities have less than 3 missing values. 
plot.categoric('SaleType', df.fulldata)
df.fulldata[is.na(df.fulldata$SaleType),c('SaleCondition')]

table(df.fulldata$SaleCondition, df.fulldata$SaleType)

# Most houses with SaleCondition = ‘Normal’ have a SaleType of ‘WD’. We’ll replace the NA accordingly.
df.fulldata$SaleType[is.na(df.fulldata$SaleType)] = 'WD'

plot.categoric('Functional', df.fulldata)
df.fulldata$Functional[is.na(df.fulldata$Functional)] = 'Typ'

# Utilities only has 1 value for NoSeWa and the rest AllPub. 
# We can drop this feature from our dataset as this house is from our training set 
plot.categoric('Utilities', df.fulldata)
which(df.fulldata$Utilities == 'NoSeWa') # in the training data set

col.drops <- c('Utilities')
df.fulldata <- df.fulldata[,!names(df.fulldata) %in% c('Utilities')]

# Zoning and building class. Check which subclass for which Zoning
df.fulldata[is.na(df.fulldata$MSZoning),c('MSZoning','MSSubClass')]
plot.categoric('MSZoning', df.fulldata)
table(df.fulldata$MSZoning, df.fulldata$MSSubClass)

# We set the Subclass related to NA values according to the most frequent subclass of the same values
df.fulldata$MSZoning[c(2217, 2905)] = 'RL'
df.fulldata$MSZoning[c(1916, 2251)] = 'RM'


# There are 23 missing values for MasVnrArea and 24 for MasVnrType. 
# We can see if both missing values come from the same houses
df.fulldata[(is.na(df.fulldata$MasVnrType)) | (is.na(df.fulldata$MasVnrArea)), c('MasVnrType', 'MasVnrArea')]

# There is just one column where you have an area value. We will replace its Type with median value
# We will set all the rest to 'None' and 0

na.omit(df.fulldata[, c('MasVnrType', 'MasVnrArea')]) %>%
  group_by(na.omit(MasVnrType)) %>%
  summarise(medianArea = median(MasVnrArea, na.rm = TRUE), counts = n()) %>%
  arrange(medianArea)

df.fulldata[2611, 'MasVnrType'] = 'BrkFace'

# The other areas and Type we can replace by O and 'None'
df.fulldata$MasVnrType[is.na(df.fulldata$MasVnrType)] = 'None'
df.fulldata$MasVnrArea[is.na(df.fulldata$MasVnrArea)] = 0

# There are 486 missing values for LotFrontage, which is quite a lot of values to fill and we can’t just replace these with 0. 
# We’re given that “LotFrontage: Linear feet of street connected to property.” 
# The area of each street connected to the house property is most likely going to have a similar area to other houses in its neighborhood. 
# We can group by each neighborhood and take the median of each LotFrontage and fill the missing values of each LotFrontage based on what neighborhood the house comes from.

df.fulldata['Nbrh.factor'] <- factor(df.fulldata$Neighborhood, levels = unique(df.fulldata$Neighborhood))

lot.by.nbrh <- df.fulldata[,c('Neighborhood','LotFrontage')] %>%
  group_by(Neighborhood) %>%
  summarise(median = median(LotFrontage, na.rm = TRUE))
lot.by.nbrh

idx = which(is.na(df.fulldata$LotFrontage))

for (i in idx){
  lot.median <- lot.by.nbrh[lot.by.nbrh == df.fulldata$Neighborhood[i],'median']
  df.fulldata[i,'LotFrontage'] <- lot.median[[1]]
}

# We can replace any missing values for Fence and MiscFeature with ‘None’ as they probably don’t have this feature with their property.
plot.categoric('Fence', df.fulldata)
df.fulldata$Fence[is.na(df.fulldata$Fence)] = 'None'

table(df.fulldata$MiscFeature)
df.fulldata$MiscFeature[is.na(df.fulldata$MiscFeature)] = 'None'

# Check that FirePlace Quality NA values come from houses with no fireplace. 
# If yes, replace with 'None'
plot.categoric('FireplaceQu', df.fulldata)
which((df.fulldata$Fireplaces > 0) & (is.na(df.fulldata$FireplaceQu)))
df.fulldata$FireplaceQu[is.na(df.fulldata$FireplaceQu)] = 'None'

# For Alley, we can find 2721 missing values only 2 options Grvl and Pave. 
# We can fill ‘None’ for houses with NA’s since they must not have any type of alley.
plot.categoric('Alley', df.fulldata)
df.fulldata$Alley[is.na(df.fulldata$Alley)] = 'None'

paste('There are', sum(sapply(df.fulldata, is.na)), 'missing values left')


# Transform every non numeric values into numeric values 

# First, we build two dataframes from the former one: 
# Take the names of: 1) numeric variables and 2) character variables
num_features <- names(which(sapply(df.fulldata, is.numeric)))
cat_features <- names(which(sapply(df.fulldata, is.character)))

# Build a dataframe just for numeric values 

df.numeric <- df.fulldata[num_features]


# To make the transformation from character values to numeric values, we build a function map.fcn
# It's very usefull when we want to transform several columns in the same.
# When we will have only column to transform, we will use as.numeric 
# cols is all the columns that we want to transform
# map.list defines the transformations we want to do (example: 'c' => 1)
# df is the dataframe which will be transformed
map.fcn <- function(cols, map.list, df){
  for (col in cols){
    df[col] <- as.numeric(map.list[df.fulldata[,col]])
  }
  return(df)
}

# In the data description, we found that:

# ExterQual: Evaluates the quality of the material on the exterior 
# 
# Ex	Excellent
# Gd	Good
# TA	Average/Typical
# Fa	Fair
# Po	Poor
# 
# ExterCond: Evaluates the present condition of the material on the exterior
# 
# Ex	Excellent
# Gd	Good
# TA	Average/Typical
# Fa	Fair
# Po	Poor

# Any columns with "Qual" or "Cond take these values. 
# What we will do is we will transform columns with Qual or Cond:
qual.cols <- c('ExterQual', 'ExterCond', 'GarageQual', 'GarageCond', 
               'FireplaceQu', 'KitchenQual', 'HeatingQC', 'BsmtQual')

# Using these values:
qual.list <- c('None' = 0, 'Po' = 1, 'Fa' = 2, 'TA' = 3, 'Gd' = 4, 'Ex' = 5)

# Let's do the transformation with our function and transform df.numeric,
# which is the dataframe with only numeric values columns
df.numeric <- map.fcn(qual.cols, qual.list, df.numeric)


# Let's do the next one: BsmtExposure: 
# Refers to walkout or garden level walls in the data desscription 
# 
# Gd	Good Exposure
# Av	Average Exposure (split levels or foyers typically score average or above)	
# Mn	Mimimum Exposure
# No	No Exposure
# NA	No Basement

bsmt.list <- c('None' = 0, 'No' = 1, 'Mn' = 2, 'Av' = 3, 'Gd' = 4)
df.numeric = map.fcn(c('BsmtExposure'), bsmt.list, df.numeric)

# We will now tranform BsmtFinTYpe 1 and 2

# BsmtFinType1: Rating of basement finished area
# 
# GLQ	Good Living Quarters
# ALQ	Average Living Quarters
# BLQ	Below Average Living Quarters	
# Rec	Average Rec Room
# LwQ	Low Quality
# Unf	Unfinshed
# NA	No Basement
# 
# BsmtFinType2: Rating of basement finished area (if multiple types)
# 
# GLQ	Good Living Quarters
# ALQ	Average Living Quarters
# BLQ	Below Average Living Quarters	
# Rec	Average Rec Room
# LwQ	Low Quality
# Unf	Unfinshed
# NA	No Basement

bsmt.fin.list <- c('None' = 0, 'Unf' = 1, 'LwQ' = 2,'Rec'= 3, 'BLQ' = 4, 'ALQ' = 5, 'GLQ' = 6)
df.numeric <- map.fcn(c('BsmtFinType1','BsmtFinType2'), bsmt.fin.list, df.numeric)

# For the rest of the transformations, we will do the transformations based on what we found
# on the data description. 


# Functional: Home functionality (Assume typical unless deductions are warranted)

functional.list <- c('None' = 0, 'Sal' = 1, 'Sev' = 2, 'Maj2' = 3, 'Maj1' = 4,
                     'Mod' = 5, 'Min2' = 6, 'Min1' = 7, 'Typ'= 8)
df.numeric['Functional'] <- as.numeric(functional.list[df.fulldata$Functional])

garage.fin.list <- c('None' = 0,'Unf' = 1, 'RFn' = 1, 'Fin' = 2)
df.numeric['GarageFinish'] <- as.numeric(garage.fin.list[df.fulldata$GarageFinish])

fence.list <- c('None' = 0, 'MnWw' = 1, 'GdWo' = 1, 'MnPrv' = 2, 'GdPrv' = 4)
df.numeric['Fence'] <- as.numeric(fence.list[df.fulldata$Fence])

MSdwelling.list <- c('20' = 1, '30'= 0, '40' = 0, '45' = 0,'50' = 0, '60' = 1, '70' = 0,
                     '75' = 0, '80' = 0, '85' = 0, '90' = 0, '120' = 1, '150' = 0,
                     '160' = 0, '180' = 0, '190' = 0)
df.numeric['NewerDwelling'] <- as.numeric(MSdwelling.list[as.character(df.fulldata$MSSubClass)])

MSZoning.list <- c('A' = 1,	'C (all)' = 2,	'FV' = 3, 'I' = 4,	'RH' = 5, 'RL' = 6,	
                   'RP' = 7,	'RM' = 8)
df.numeric['MSZoning'] <- as.numeric(MSZoning.list[as.character(df.fulldata$MSZoning)])

LandContour.list <- c('Lvl' = 1, 'Bnk' = 2, 'HLS' = 3, 'Low' = 4)
df.numeric['LandContour'] <- as.numeric(LandContour.list[as.character(df.fulldata$LandContour)])

LotConfig.list <- c('Inside' = 1, 'FR2' = 2, 'Corner' = 3, 'CulDSac' = 4, 'FR3' = 5)
df.numeric['LotConfig'] <- as.numeric(LotConfig.list[as.character(df.fulldata$LotConfig)])



# For some variables, we will just transform values into 0 and 1.
# For example, for lotShape, there is one value for a regular shape and all the others 
# are from irregular shapes => Let's transform in 0 and 1. We will use the same technic for
# some other features, when possible.

df.numeric['LotShape'] <- (df.fulldata$LotShape == 'Reg') * 1
df.numeric['Landcontour'] <- (df.fulldata$LandContour == 'Lvl') * 1
df.numeric['LandSlope'] <- (df.fulldata$LandSlope == 'Gtl') * 1
df.numeric['Electrical'] <- (df.fulldata$Electrical == 'SBrkr') * 1
df.numeric['GarageType'] <- (df.fulldata$GarageType == 'Detchd') * 1
df.numeric['PavedDrive'] <- (df.fulldata$PavedDrive == 'Y') * 1
df.numeric['WoodDeckSF'] <- (df.fulldata$WoodDeckSF > 0) * 1
df.numeric['X2ndFlrSF'] <- (df.fulldata$X2ndFlrSF > 0) * 1
df.numeric['MasVnrArea'] <- (df.fulldata$MasVnrArea > 0) * 1
df.numeric['MiscFeature'] <- (df.fulldata$MiscFeature == 'Shed') * 1
df.numeric['Street'] <- as.integer(df.fulldata$Street == 'Pave')
df.numeric['Alley'] <- (df.fulldata$Alley == 'Pave') * 1
df.numeric['Condition1'] <- (df.fulldata$Condition1 == 'Norm') * 1
df.numeric['Condition2'] <- (df.fulldata$Condition2 == 'Norm') * 1


# The last feature we will treat carefully is "Neighborhood". Indeed, 
# some of the neighborhood show a big price difference comparing with ohter:

neighborhood_distr <- training_data[,c('Neighborhood','SalePrice')] %>%
  group_by(Neighborhood) %>%
  summarise(median.price = median(SalePrice, na.rm = TRUE)) %>%
  arrange(median.price) %>%
  mutate(nhbr.sorted = factor(Neighborhood, levels=Neighborhood))

neighborhood_distr <- arrange(neighborhood_distr, desc(median.price))

# We will give the value one for the 8 top Neighborhood, and 0 to the rest:

rich.neighborhood <- c('ClearCr' ,'Crawfor', 'Somerst', 'Timber', 'StoneBr', 'NoRidge', 'NridgeHt')
df.numeric['Neighborhood'] <- (df.fulldata$Neighborhood %in% rich.neighborhood) *1

# Let's finish the transformation for all the other datas, transforming last features in 
# dummy variables 

dummies_colstoadd <- select(df.fulldata, BldgType, HouseStyle, RoofStyle, RoofMatl, Exterior1st,
                                                                Exterior2nd, MasVnrType,
                                                                Foundation, BsmtCond, Heating,
                                                                CentralAir, PoolQC, SaleType,
                                                                SaleCondition, Nbrh.factor)
dummies_colstoadd <- dummy_cols(dummies_colstoadd)
df.numeric <- cbind(df.numeric, dummies_colstoadd)

# Delete the former columns 

df.numeric$BldgType <- NULL
df.numeric$HouseStyle <- NULL
df.numeric$RoofStyle <- NULL
df.numeric$RoofMatl <- NULL
df.numeric$Exterior1st <- NULL
df.numeric$Exterior2nd <- NULL
df.numeric$MasVnrType <- NULL
df.numeric$Foundation <- NULL
df.numeric$BsmtCond <- NULL
df.numeric$Heating <- NULL
df.numeric$CentralAir <- NULL
df.numeric$PoolQC <- NULL
df.numeric$SaleType <- NULL
df.numeric$SaleCondition <- NULL
df.numeric$Nbrh.factor <- NULL


paste('There are', sum(sapply(df.numeric, is.character)), 'character columns left')

# No more character values left










