library(h2o)
library(nnet)
library(plyr)
library(dplyr)
library(purrr)
library(scales)
library(caTools)
library(lime)
h2o.init()



#############################
##      Pre Processing     ##
#############################
dat = read.csv("C:/Users/rose.anwuri/Documents/TheArtandScienceofData/Consitent Billionaire Guide/data/billionaire_data2.csv")
dat1=dat %>%
  filter(Cluster !="The Newbie")
data = dat1 %>% 
  select(-Detail1,-Detail2) %>%
  as.h2o()

splits = h2o.splitFrame(data,ratios = c(0.6,0.2),destination_frames = c("train", "valid", "test"), seed = 1234)
train = h2o.getFrame("train")
val = h2o.getFrame("valid")
test = h2o.getFrame("test")
#After some feature selection, these are the final features
features=2:21
response=22


##########################################
##Model Selection, Tuning and Validation## 
##           in one step!               ##
#########################################

#Select best model (already tuned) using the automl fuction
#Fix maximum number of models to be trained as 10
model_selection=h2o.automl(x=features,y=response,training_frame = train,validation_frame = val,max_models = 10,stopping_metric = "AUC")


#Extract the best model
final_model = model_selection@leader

model = do.call(h2o.gbm,
                {
                  p <- final_model@parameters
                  p$model_id = NULL          ## do not overwrite the original grid model
                  p$training_frame = data      ## use the full dataset
                  p$validation_frame = NULL  ## no validation frame
                  p$nfolds = 5               ## cross-validation
                  p
                })

#Save Model to be loaded into Shiny App!
h2o.saveModel(model,"local_model1")

#Lime Predictions [Optional]
df_lime = as.data.frame(data)[,c(features,response)]
df_lime=read.csv("C:/Users/rose.anwuri/Documents/TheArtandScienceofData/Consitent Billionaire Guide/app/billionaire_data_for_ml.csv")
model=h2o.loadModel("C:/Users/rose.anwuri/Documents/TheArtandScienceofData/Consitent Billionaire Guide/app/local_model")
df_lime$prediction =predict(model,data)[,1] %>% as.vector()

explainer <- lime::lime(
  df_lime, 
  model          = model, 
  bin_continuous = T)

explanation <- lime::explain(
  df_lime[c(7)], 
  explainer    = explainer, 
  n_labels     = 1, 
  n_features   = 8,
  kernel_width = 0.5)

plot_features(explanation)
  
