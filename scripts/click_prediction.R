########################### Readme ###############################
#
#   Author:       Tim Siwula
#   Proposal:     http://bit.ly/2gcCLQ4
#   Kaggle:       http://bit.ly/2gMVpPG
#   Github:       http://bit.ly/2gZoTwy
#   Data:         http://bit.ly/2fQ0LHW
#
# predictors:
#           "display_id", "ad_id", "clicked", "document_id", "topic_id", "confidence_level"
#
# response:
#         "clicked"
#
# future features: entity_id, entity_conf
##################################################################

########################### Setup ################################
library(knitr)            #install.packages("knitr")
library(markdown)         #install.packages("markdown")
library(ISLR)
library(tree)
require("RPostgreSQL")    #install.packages("RPostgreSQL")
require(randomForest)     #install.packages('randomForest', repos="http://cran.r-project.org")
require(tree)             #install.packages("tree")
require(knitr)
library(knitr)
library(markdown)
library(e1071)
require("e1071")         #install.packages("e1071", dep = TRUE)
library(ROCR)            #install.packages("ROCR", dep = TRUE)
require("ROCR")
knit("click_prediction.R")  #transform the .Rmd to a markdown (.md) file.
####################################################################################

########################### SET UP DATABASE CONNECTION ############################
driver <- dbDriver("PostgreSQL")   # loads the PostgreSQL driver
# creates a connection to the postgres database
# note that "con" will be used later in each connection to the database
connection <- dbConnect(driver, dbname = "clickprediction",
                        host = "localhost", port = 5432,
                        user = "admin", password = "admin")
# confirm the tables are accessible
dbExistsTable(connection, "clicks_train")
##################################################################################

########################### QUERY THE DATABASE ##################################
# 1)
# try to find features related to ad_id.
# here we join click_train and promoted-content with ad_id.

# look at clicks_train first
getClicksTrain="select * from clicks_train limit 10 "
clicks_train = dbGetQuery(connection, getClicksTrain)
clicks_train

# look at promoted_content next
getPromotedContent="select * from promoted_content limit 10"
promoted_content = dbGetQuery(connection, getPromotedContent)
promoted_content

# join click_train and promoted-content with ad_id new table
# 500k apears to be stable with rstudio.
join_query = "
select t.display_id, t.ad_id, t.clicked, d.document_id,
d.topic_id, d.confidence_level, p.advertiser_id
from clicks_train t, promoted_content p, documents_topics d
where t.ad_id = p.ad_id and p.document_id = d.document_id 
limit 500000;"
merged_table=dbGetQuery(connection, join_query)
head(merged_table, 3)
dim(merged_table)
####################################################################################

########################### CREATE AND WRITE NEW TABLE #############################
dbWriteTable(connection, "merged_table", merged_table, row.names=FALSE)

# look at the new table
getMergedTable="select * from merged_table limit 500000"
new_table = dbGetQuery(connection, getMergedTable)

# list the structure of mydata
str(new_table)
hist(new_table$confidence_level)
hist(new_table$clicked)
hist(new_table$display_id)
hist(new_table$ad_id)
hist(new_table$document_id)
hist(new_table$topic_id)

####################################################################################

########################### GET 50/50 CLICKED ######################################
# balanced data set
ones = new_table[new_table$clicked>0, 50000]
length(ones)
length(new_table)

onesVersion2 = ones = subset(new_table, clicked>0)
dim(onesVersion2)

zeros = subset(new_table, clicked < 1)
dim(zeros)

undersampled_zeros = zeros[sample(nrow(zeros), 50000), ]
table(undersampled_zeros$clicked)
table(ones$clicked)
dim(undersampled_zeros)
dim(ones)
names(undersampled_zeros)
names(ones)

final_dataset <- merge(undersampled_zeros, ones, all.x=TRUE, all.y=TRUE)

# FINAL DATA SET
dim(final_dataset)
head(final_dataset, n=5)
####################################################################################

################   DATA SKEWNESS    ##############
my_class = final_dataset$clicked
###################################################

########################### CREATE TRAINING AND TEST SET ###########################
# define partition ratio
partition_size = floor(0.80 * nrow(final_dataset)) ## 80% of the sample size
set.seed(123) ## set the seed to make your partition reproductible
partition_index <- sample(seq_len(nrow(final_dataset)), size = partition_size)

# set training set
local_train_set <- final_dataset[partition_index, ]
local_train_set = sample(local_train_set, length(local_train_set))

# set test set
local_test_set <- final_dataset[-partition_index, ]
local_test_set = sample(local_test_set, length(local_test_set))

# LOCAL TEST SET
dim(local_test_set)
head(local_test_set, n=5)

# LOCAL TRAIN SET
dim(local_train_set)
head(local_train_set, n=5)
#########################################################################

################   MODEL COMPARISON    ##############
###################################################
# model 1:
# type: glm
# predictors: topic_id, coconfidence_leve
# accuracy: 61%
###################################################
m1_fit=glm(clicked ~ topic_id+confidence_level, data=train,family=binomial)
summary(m1_fit)
m1_probs=predict(m1_fit,newdata=test,type="response") 
m1=ifelse(m1_probs >0.5,1,0)
table(m1,test$clicked)
acu1=mean(m1==test$clicked)     # numberic accuracy
acu1
###################################################

###################################################
# model 2:
# type: glm
# predictors: topic_id, coconfidence_levelnf, document_id, topic_id
# accuracy: 62%
###################################################
m2_fit=glm(clicked ~ topic_id+confidence_level+document_id+topic_id, data=train,family=binomial)
summary(m2_fit)
m2_probs=predict(m2_fit,newdata=test,type="response") 
m2=ifelse(m2_probs >0.5,1,0)
table(m2,test$clicked)
acu2=mean(m2==test$clicked)      # numberic accuracy
acu2
###################################################

###################################################
# model 3:
# type: random forest
# predictors: topic_id, coconfidence_level
# accuracy: 69%
###################################################
m3_fit=randomForest(clicked ~ topic_id+confidence_level, data=train, ntree=400)
m3_probs=predict(m3_fit,test)
m3=ifelse(m3_probs >0.5,1,0)
table(m3, test$clicked)
acu3 = mean(m3 == test$clicked)     # numberic accuracy
acu3
###################################################

####### PLOT ACCURACY RESULTS GRAPH ########
x_models <- numeric(0)
x_models[1] =  "m1"
x_models[2] =  "m2"
x_models[3] =  "m3"

y_accuracy = numeric(0)
y_accuracy[1] =  acu1
y_accuracy[2] =  acu2
y_accuracy[3] =  acu3
colours <- c("blue", "yellow", "green")
acu_all <- c(acu1, acu2, acu3)
barplot(col=colours,acu_all, main="Accuracy Comparison", xlab="Models", ylab="Accuracy", names.arg=c("m1","m2","m3"),
        border="red")
################################################

####### FUTURE FEATURES ########
# create another model with different features
#m1 : glm with topic_id, conf
#m2: rf with topic_id, conf
#m3: glm with topic_id, conf, category_id, category_conf  
#m4: topics_id+confidence_level+advertiser_id
#models:       #x-axis: m1, m2
#accuracy:    #y-axis: 0.60, 0.69
################################################

################                 DECISION TREE             ##############
# fit on clicked all features excluding clicked using the final dataset
clicked_tree = tree(clicked~.-clicked,final_dataset)
summary(clicked_tree)
plot(clicked_tree)
text(clicked_tree,pretty=0)

# SEE IF PRUING THE TREE WILL IMPROVE PERFORMANCE
cv_clicked_tree = cv.tree(clicked_tree)
plot(cv_clicked_tree$size, cv_clicked_tree$dev, type='b', main="cross-validation default")

pruned = prune.tree(clicked_tree, best=5)
plot(pruned)
text(pruned,pretty=0)

# USE UNPRUNED TREE TO MAKE PREDICTIONS ON THE TEST SET
# IF BETTER ...
yhat = predict(clicked_tree, newdata = final_dataset[-partition_index, ])
clicked_test=final_dataset[-partition_index, "clicked"]
plot(yhat,clicked_test)
abline(0,1)
mean((yhat-clicked_test)^2)
head(yhat, n=5)
str(yhat)
length(yhat)
summary(yhat)
# the test set MSE associated with the regreeesion tree
# is 0.21
########################################################

################   LOGISTIC REGRESSION    ##############
summary(final_dataset)
cor(final_dataset)
partition_size = floor(0.80 * nrow(final_dataset)) ## 80% of the sample size

# remove empty values
is.na(final_dataset) # if TRUE, then replace them with 0
final_dataset[is.na(final_dataset)] <- 0 # Not sure replacing NA with 0 will have effect on your model
#train=sample(1:nrow(final_dataset),partition_size)

partition_size <- floor(0.75 * nrow(final_dataset))
set.seed(123)

train_ind <- sample(seq_len(nrow(final_dataset)), size = partition_size)
train <- final_dataset[train_ind, ]
test <- final_dataset[-train_ind, ]

# regression
#log_reg_fit=glm(clicked~ . -clicked,data=final_dataset, subset = train,family=binomial)
log_reg_fit=glm(clicked ~ topic_id+confidence_level, data=train,family=binomial)
summary(log_reg_fit)

glm.probs=predict(log_reg_fit,newdata=test,type="response") 
glm.pred=ifelse(glm.probs >0.5,1,0)

#accuracy numberic
table(glm.pred,test$clicked)
mean(glm.pred==test$clicked)

#accuracy visuals
par(mfrow=c(2,2))
plot(log_reg_fit)

#accuracy numeric
summary(log_reg_fit)
log_reg_fit
##################################################

################   RANDOM FORESTS    ##############
#train=sample(1:nrow(final_dataset),300)
#rf=randomForest(clicked~.-clicked,data=final_dataset,subset=train)
#test.err=with(test[-train,],mean((medv-pred)^2))

rf=randomForest(clicked ~ topic_id+confidence_level, data=train, ntree=400)
rf.probs=predict(rf,test)
rf.pred=ifelse(rf.probs >0.5,1,0)
# this models accuracy
table(rf.pred, test$clicked)
mean(rf.pred == test$clicked)
###################################################

####### KAGGLE SAMPLE SUBMISSION FORMAT ########
#"display_id","ad_id"
#16874594,"170392 172888 162754 150083 66758 180797"
#16874595,"8846 143982 30609"
################################################